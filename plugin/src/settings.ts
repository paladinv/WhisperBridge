import { randomUUID } from "node:crypto";
import { mkdir, readFile, rename, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { TRANSCRIPT_MARKER } from "./constants";
import {
  DEFAULT_MODEL_ID,
  LANGUAGE_OPTIONS,
  MODEL_CATALOG,
  modelByID,
  type ModelDescriptor
} from "./modelCatalog";
import { dataDirectory } from "./modelStore";

export const INHERIT_SETTING = "__whisperbridge_default__";
export type SettingsScope = "chat" | "inherit";

export interface SpeechSettingsValues {
  modelID: string;
  language: string;
  includeFilename: boolean;
  diarization?: boolean;
  timestampGranularity?: "none" | "segment" | "word";
  compact?: boolean;
  removeFillers?: boolean;
  saveToLibrary?: boolean;
  preset?: "fast" | "balanced" | "accurate";
  strategy?: "greedy" | "beam";
  beamSize?: number;
  greedyBestOf?: number;
  patience?: number;
  temperature?: number;
  temperatureIncrement?: number;
  initialPrompt?: string;
  noSpeechThreshold?: number;
  logProbabilityThreshold?: number;
  timeRange?: { start: number; end: number };
}

export interface ResolvedSpeechSettings extends SpeechSettingsValues {
  scope: SettingsScope;
}

export interface SpeechSettingsUpdate {
  modelID?: string;
  language?: string;
  includeFilename?: boolean;
  diarization?: boolean;
  timestampGranularity?: "none" | "segment" | "word";
  compact?: boolean;
  removeFillers?: boolean;
  saveToLibrary?: boolean;
  preset?: "fast" | "balanced" | "accurate";
  strategy?: "greedy" | "beam";
  beamSize?: number;
  greedyBestOf?: number;
  patience?: number;
  temperature?: number;
  temperatureIncrement?: number;
  initialPrompt?: string;
  noSpeechThreshold?: number;
  logProbabilityThreshold?: number;
  timeRange?: { start: number; end: number };
}

export interface VersionedGlobalSettings extends SpeechSettingsUpdate {
  version: 1 | 2;
}

export interface PluginUISettings {
  model: string;
  language: string;
  filename: string;
}

export type ParsedDirective =
  | { kind: "chat"; update: SpeechSettingsUpdate; instruction: string }
  | { kind: "global"; update: SpeechSettingsUpdate; instruction: string }
  | { kind: "resetChat"; update: {}; instruction: string }
  | { kind: "resetGlobal"; update: {}; instruction: string };

const BUILTIN_SETTINGS: SpeechSettingsValues = {
  modelID: DEFAULT_MODEL_ID,
  language: "auto",
  includeFilename: true,
  diarization: false,
  timestampGranularity: "segment",
  compact: false,
  removeFillers: false,
  saveToLibrary: false,
  preset: "balanced",
  strategy: "greedy",
  beamSize: 5,
  greedyBestOf: 5,
  patience: 1,
  temperature: 0,
  temperatureIncrement: 0.2,
  noSpeechThreshold: 0.6,
  logProbabilityThreshold: -1
};

const MODEL_ALIASES: Readonly<Record<string, string>> = Object.freeze({
  everyday: "whisper-base-multilingual",
  smallest: "whisper-tiny-multilingual",
  better: "whisper-small-multilingual",
  best: "whisper-large-v3-turbo-q5",
  "fast-english": "moonshine-tiny-english",
  european: "parakeet-tdt-0.6b-v3-mlx-8bit",
  "high-accuracy": "cohere-transcribe-2b-mlx-4bit",
  granite: "granite-4.0-1b-speech-mlx-5bit"
});

const validLanguages = new Set(LANGUAGE_OPTIONS.map(option => option.value));
const directiveHelp = "Use '/wb model=better diarize=on timestamps=word preset=accurate' and see WhisperBridge → … → View README.";

const presets = {
  fast: { strategy: "greedy" as const, greedyBestOf: 1 },
  balanced: { strategy: "greedy" as const, greedyBestOf: 5 },
  accurate: { strategy: "beam" as const, beamSize: 5, patience: 1 }
};

function parseOnOff(key: string, value: string): boolean {
  if (value !== "on" && value !== "off") throw directiveError(`The ${key} setting must be 'on' or 'off'.`);
  return value === "on";
}

export function parseTimestamp(value: string): number {
  const pieces = value.split(":");
  if (pieces.length < 1 || pieces.length > 3 || pieces.some(piece => !/^\d+(?:\.\d+)?$/.test(piece))) {
    throw directiveError(`Invalid timestamp '${value}'.`);
  }
  let seconds = 0;
  for (const piece of pieces) seconds = seconds * 60 + Number(piece);
  if (!Number.isFinite(seconds) || seconds < 0) throw directiveError(`Invalid timestamp '${value}'.`);
  return seconds;
}

function directiveError(message: string): Error {
  return new Error(`${message} ${directiveHelp}`);
}

export function resolveModelName(value: string): ModelDescriptor {
  const normalized = value.trim().toLowerCase();
  const model = modelByID(MODEL_ALIASES[normalized] ?? normalized);
  if (!model) throw directiveError(`Unknown speech model '${value}'.`);
  if (!model.available) throw directiveError(model.unavailableReason ?? `${model.displayName} is unavailable.`);
  return model;
}

function parseUpdate(tokens: string[]): SpeechSettingsUpdate {
  if (tokens.length === 0) throw directiveError("The WhisperBridge command has no settings.");
  const update: SpeechSettingsUpdate = {};
  const seen = new Set<string>();
  for (const token of tokens) {
    const separator = token.indexOf("=");
    if (separator <= 0 || separator === token.length - 1) {
      throw directiveError(`Invalid WhisperBridge setting '${token}'.`);
    }
    const key = token.slice(0, separator).toLowerCase();
    const rawValue = token.slice(separator + 1);
    const value = rawValue.toLowerCase();
    if (seen.has(key)) throw directiveError(`WhisperBridge setting '${key}' was provided more than once.`);
    seen.add(key);
    switch (key) {
      case "model":
        update.modelID = resolveModelName(value).id;
        break;
      case "language":
        if (!validLanguages.has(value)) throw directiveError(`Unknown spoken language '${value}'.`);
        update.language = value;
        break;
      case "filename":
        update.includeFilename = parseOnOff(key, value);
        break;
      case "diarize": update.diarization = parseOnOff(key, value); break;
      case "compact": update.compact = parseOnOff(key, value); break;
      case "fillers": update.removeFillers = parseOnOff(key, value); break;
      case "library": update.saveToLibrary = parseOnOff(key, value); break;
      case "timestamps":
        if (!["none", "segment", "word"].includes(value)) throw directiveError("Timestamps must be 'none', 'segment', or 'word'.");
        update.timestampGranularity = value as SpeechSettingsUpdate["timestampGranularity"];
        break;
      case "preset":
        if (!(value in presets)) throw directiveError("Preset must be 'fast', 'balanced', or 'accurate'.");
        update.preset = value as keyof typeof presets;
        Object.assign(update, presets[update.preset]);
        break;
      case "strategy":
        if (value !== "greedy" && value !== "beam") throw directiveError("Strategy must be 'greedy' or 'beam'.");
        update.strategy = value;
        break;
      case "beam-size": update.beamSize = integerSetting(key, value, 1, 10); break;
      case "best-of": update.greedyBestOf = integerSetting(key, value, 1, 10); break;
      case "patience": update.patience = numberSetting(key, value, 0, 2); break;
      case "temperature": update.temperature = numberSetting(key, value, 0, 1); break;
      case "temperature-increment": update.temperatureIncrement = numberSetting(key, value, 0, 1); break;
      case "no-speech-threshold": update.noSpeechThreshold = numberSetting(key, value, 0, 1); break;
      case "logprob-threshold": update.logProbabilityThreshold = numberSetting(key, value, -5, 0); break;
      case "prompt":
        try {
          update.initialPrompt = decodeURIComponent(rawValue).slice(0, 1000);
        } catch {
          throw directiveError("prompt must use valid percent encoding.");
        }
        break;
      case "start":
        update.timeRange = { start: parseTimestamp(value), end: update.timeRange?.end ?? Number.NaN };
        break;
      case "end":
        update.timeRange = { start: update.timeRange?.start ?? Number.NaN, end: parseTimestamp(value) };
        break;
      default:
        throw directiveError(`Unknown WhisperBridge setting '${key}'.`);
    }
  }
  if (update.timeRange && (!Number.isFinite(update.timeRange.start) || !Number.isFinite(update.timeRange.end))) {
    throw directiveError("Provide start and end together.");
  }
  if (update.timeRange && update.timeRange.end <= update.timeRange.start) throw directiveError("The end time must be after the start time.");
  return update;
}

function integerSetting(key: string, value: string, minimum: number, maximum: number): number {
  if (!/^\d+$/.test(value)) throw directiveError(`${key} must be a whole number from ${minimum} through ${maximum}.`);
  return numberSetting(key, value, minimum, maximum);
}

function numberSetting(key: string, value: string, minimum: number, maximum: number): number {
  const number = Number(value);
  if (!Number.isFinite(number) || number < minimum || number > maximum) throw directiveError(`${key} must be from ${minimum} through ${maximum}.`);
  return number;
}

export function parseDirective(text: string): ParsedDirective | null {
  const lines = text.split(/\r?\n/);
  const lineIndex = lines.findIndex(line => line.trim().length > 0);
  if (lineIndex < 0 || !/^\/wb(?:\s|$)/i.test(lines[lineIndex].trim())) return null;
  const command = lines[lineIndex].trim().split(/\s+/);
  const instruction = [...lines.slice(0, lineIndex), ...lines.slice(lineIndex + 1)].join("\n").trim();
  const args = command.slice(1);
  if (args.length === 1 && args[0].toLowerCase() === "reset") {
    return { kind: "resetChat", update: {}, instruction };
  }
  if (args[0]?.toLowerCase() === "default") {
    const globalArgs = args.slice(1);
    if (globalArgs.length === 1 && globalArgs[0].toLowerCase() === "reset") {
      return { kind: "resetGlobal", update: {}, instruction };
    }
    const update = parseUpdate(globalArgs);
    if (update.timeRange) throw directiveError("start and end apply only to the current audio prompt.");
    return { kind: "global", update, instruction };
  }
  return { kind: "chat", update: parseUpdate(args), instruction };
}

export function settingsFilePath(environment: NodeJS.ProcessEnv = process.env): string {
  return path.join(dataDirectory(environment), "settings-v2.json");
}

function validateStoredSettings(value: unknown): VersionedGlobalSettings {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("is not a JSON object");
  const record = value as Record<string, unknown>;
  const allowed = new Set(["version", "modelID", "language", "includeFilename", "diarization", "timestampGranularity", "compact", "removeFillers", "saveToLibrary", "preset", "strategy", "beamSize", "greedyBestOf", "patience", "temperature", "temperatureIncrement", "initialPrompt", "noSpeechThreshold", "logProbabilityThreshold"]);
  if (Object.keys(record).some(key => !allowed.has(key))) throw new Error("contains an unknown setting");
  if (record.version !== 2) throw new Error("has an unsupported version");
  if (record.modelID !== undefined) resolveModelName(String(record.modelID));
  if (record.language !== undefined && (typeof record.language !== "string" || !validLanguages.has(record.language))) {
    throw new Error("contains an invalid language");
  }
  if (record.includeFilename !== undefined && typeof record.includeFilename !== "boolean") {
    throw new Error("contains an invalid filename setting");
  }
  for (const key of ["diarization", "compact", "removeFillers", "saveToLibrary"] as const) {
    if (record[key] !== undefined && typeof record[key] !== "boolean") throw new Error(`contains an invalid ${key} setting`);
  }
  if (record.initialPrompt !== undefined && (typeof record.initialPrompt !== "string" || record.initialPrompt.length > 1_000)) {
    throw new Error("contains an invalid initial prompt");
  }
  const candidate = mergeSettings(record as SpeechSettingsUpdate);
  validateResolved(candidate);
  return record as unknown as VersionedGlobalSettings;
}

export async function loadGlobalSettings(
  environment: NodeJS.ProcessEnv = process.env
): Promise<VersionedGlobalSettings> {
  const file = settingsFilePath(environment);
  try {
    return validateStoredSettings(JSON.parse(await readFile(file, "utf8")));
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") {
      const legacy = path.join(path.dirname(file), "settings-v1.json");
      try {
        const old = JSON.parse(await readFile(legacy, "utf8")) as Record<string, unknown>;
        if (old.version === 1) return { version: 2, modelID: old.modelID as string | undefined, language: old.language as string | undefined, includeFilename: old.includeFilename as boolean | undefined };
      } catch (legacyError) {
        if ((legacyError as NodeJS.ErrnoException).code !== "ENOENT") throw new Error(`WhisperBridge could not migrate '${legacy}': ${(legacyError as Error).message}`);
      }
      return { version: 2 };
    }
    throw new Error(`WhisperBridge could not read its global settings at '${file}': ${(error as Error).message}`);
  }
}

let settingsWriteQueue: Promise<void> = Promise.resolve();

export function saveGlobalSettings(
  update: SpeechSettingsUpdate | null,
  environment: NodeJS.ProcessEnv = process.env
): Promise<void> {
  const operation = settingsWriteQueue.then(async () => {
    const file = settingsFilePath(environment);
    if (update === null) {
      await rm(file, { force: true });
      return;
    }
    const current = await loadGlobalSettings(environment);
    const next: VersionedGlobalSettings = { ...current, ...update, version: 2 };
    validateStoredSettings(next);
    await mkdir(path.dirname(file), { recursive: true, mode: 0o700 });
    const temporary = `${file}.partial-${randomUUID()}`;
    try {
      await writeFile(temporary, `${JSON.stringify(next, null, 2)}\n`, { encoding: "utf8", mode: 0o600 });
      await rename(temporary, file);
    } catch (error) {
      await rm(temporary, { force: true });
      throw error;
    }
  });
  settingsWriteQueue = operation.catch(() => {});
  return operation;
}

function uiUpdate(ui: PluginUISettings): SpeechSettingsUpdate {
  const update: SpeechSettingsUpdate = {};
  if (ui.model !== INHERIT_SETTING) update.modelID = ui.model;
  if (ui.language !== INHERIT_SETTING) update.language = ui.language;
  if (ui.filename === "include") update.includeFilename = true;
  if (ui.filename === "omit") update.includeFilename = false;
  return update;
}

function mergeSettings(...updates: Array<SpeechSettingsUpdate | undefined>): SpeechSettingsValues {
  const merged = { ...BUILTIN_SETTINGS };
  for (const update of updates) {
    if (!update) continue;
    Object.assign(merged, Object.fromEntries(Object.entries(update).filter(([key, value]) => key !== "version" && value !== undefined)));
  }
  return merged;
}

function validateResolved(settings: SpeechSettingsValues): void {
  if (settings.timestampGranularity !== undefined && !["none", "segment", "word"].includes(settings.timestampGranularity)) throw new Error("contains invalid timestamps");
  if (settings.preset !== undefined && !["fast", "balanced", "accurate"].includes(settings.preset)) throw new Error("contains an invalid preset");
  if (settings.strategy !== undefined && !["greedy", "beam"].includes(settings.strategy)) throw new Error("contains an invalid strategy");
  integerSetting("beam-size", String(settings.beamSize ?? 5), 1, 10);
  integerSetting("best-of", String(settings.greedyBestOf ?? 5), 1, 10);
  numberSetting("patience", String(settings.patience ?? 1), 0, 2);
  numberSetting("temperature", String(settings.temperature ?? 0), 0, 1);
  numberSetting("temperature-increment", String(settings.temperatureIncrement ?? 0.2), 0, 1);
  numberSetting("no-speech-threshold", String(settings.noSpeechThreshold ?? 0.6), 0, 1);
  numberSetting("logprob-threshold", String(settings.logProbabilityThreshold ?? -1), -5, 0);
}

export function resolveSettings(options: {
  directive: ParsedDirective | null;
  history: ResolvedSpeechSettings | null;
  ui: PluginUISettings;
  global: VersionedGlobalSettings;
}): ResolvedSpeechSettings {
  const base = mergeSettings(options.global, uiUpdate(options.ui));
  const { directive, history } = options;
  if (directive?.kind === "resetChat" || directive?.kind === "resetGlobal") return { ...base, scope: "inherit" };
  if (directive?.kind === "global") return { ...mergeSettings(base, directive.update), scope: "inherit" };
  if (directive?.kind === "chat") {
    const inherited = history?.scope === "chat" ? history : { ...base, scope: "inherit" as const };
    return { ...mergeSettings(inherited, directive.update), scope: "chat" };
  }
  if (history?.scope === "chat") return history;
  return { ...base, scope: "inherit" };
}

export function formatSettingsLine(settings: ResolvedSpeechSettings): string {
  const model = modelByID(settings.modelID);
  if (!model) throw new Error(`Unknown speech model '${settings.modelID}'.`);
  const source = settings.scope === "chat" ? "chat" : "default";
  const name = model.displayName.split(" · ")[0];
  const filename = settings.includeFilename ? "included" : "omitted";
  const visible = `WhisperBridge settings (${source}): ${name} [${model.id}] · language ${settings.language} · filename ${filename}` +
    ` · diarization ${settings.diarization ? "on" : "off"} · timestamps ${settings.timestampGranularity ?? "segment"}` +
    ` · compact ${settings.compact ? "on" : "off"} · fillers ${settings.removeFillers ? "on" : "off"}` +
    ` · library ${settings.saveToLibrary ? "on" : "off"} · preset ${settings.preset ?? "balanced"}`;
  const decoder = {
    strategy: settings.strategy, beamSize: settings.beamSize, greedyBestOf: settings.greedyBestOf,
    patience: settings.patience, temperature: settings.temperature, temperatureIncrement: settings.temperatureIncrement,
    initialPrompt: settings.initialPrompt, noSpeechThreshold: settings.noSpeechThreshold,
    logProbabilityThreshold: settings.logProbabilityThreshold
  };
  return `${visible}\nWhisperBridge decoder: ${encodeURIComponent(JSON.stringify(decoder))}`;
}

const markerPattern = new RegExp(
  `^${TRANSCRIPT_MARKER.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\n` +
  "WhisperBridge settings \\((chat|default)\\): [^\\n]* \\[([a-z0-9.-]+)\\] · language ([a-z0-9-]+) · filename (included|omitted)" +
  "(?: · diarization (on|off) · timestamps (none|segment|word) · compact (on|off) · fillers (on|off) · library (on|off) · preset (fast|balanced|accurate))?(?:\\n|$)"
);

export function parseSettingsMarker(text: string): ResolvedSpeechSettings | null {
  const match = markerPattern.exec(text);
  if (!match) return null;
  const model = modelByID(match[2]);
  if (!model?.available || !validLanguages.has(match[3])) return null;
  const preset = (match[10] as SpeechSettingsValues["preset"] | undefined) ?? "balanced";
  let decoder: SpeechSettingsUpdate = presets[preset];
  const decoderLine = text.split(/\r?\n/, 4)[2];
  if (decoderLine?.startsWith("WhisperBridge decoder: ")) {
    try {
      const candidate = JSON.parse(decodeURIComponent(decoderLine.slice("WhisperBridge decoder: ".length))) as Record<string, unknown>;
      const allowed = new Set(["strategy", "beamSize", "greedyBestOf", "patience", "temperature", "temperatureIncrement", "initialPrompt", "noSpeechThreshold", "logProbabilityThreshold"]);
      if (!candidate || Array.isArray(candidate) || Object.keys(candidate).some(key => !allowed.has(key))) return null;
      decoder = candidate as SpeechSettingsUpdate;
      validateResolved(mergeSettings(decoder));
    } catch { return null; }
  }
  return {
    ...BUILTIN_SETTINGS,
    ...decoder,
    modelID: model.id,
    language: match[3],
    includeFilename: match[4] === "included",
    diarization: match[5] === "on",
    timestampGranularity: (match[6] as SpeechSettingsValues["timestampGranularity"] | undefined) ?? "segment",
    compact: match[7] === "on",
    removeFillers: match[8] === "on",
    saveToLibrary: match[9] === "on",
    preset,
    scope: match[1] === "chat" ? "chat" : "inherit"
  };
}

export function latestHistorySettings(messages: readonly string[]): ResolvedSpeechSettings | null {
  for (let index = messages.length - 1; index >= 0; index -= 1) {
    const parsed = parseSettingsMarker(messages[index]);
    if (parsed) return parsed;
  }
  return null;
}

export const MODEL_COMMAND_ALIASES = MODEL_ALIASES;
export const AVAILABLE_MODEL_IDS = MODEL_CATALOG.filter(model => model.available).map(model => model.id);
