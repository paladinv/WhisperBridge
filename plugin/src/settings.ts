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
}

export interface ResolvedSpeechSettings extends SpeechSettingsValues {
  scope: SettingsScope;
}

export interface SpeechSettingsUpdate {
  modelID?: string;
  language?: string;
  includeFilename?: boolean;
}

export interface VersionedGlobalSettings extends SpeechSettingsUpdate {
  version: 1;
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
  includeFilename: true
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
const directiveHelp = "Use '/wb model=better language=auto filename=on' and see WhisperBridge → … → View README.";

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
    const value = token.slice(separator + 1).toLowerCase();
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
        if (value !== "on" && value !== "off") {
          throw directiveError("The filename setting must be 'on' or 'off'.");
        }
        update.includeFilename = value === "on";
        break;
      default:
        throw directiveError(`Unknown WhisperBridge setting '${key}'.`);
    }
  }
  return update;
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
    return { kind: "global", update: parseUpdate(globalArgs), instruction };
  }
  return { kind: "chat", update: parseUpdate(args), instruction };
}

export function settingsFilePath(environment: NodeJS.ProcessEnv = process.env): string {
  return path.join(dataDirectory(environment), "settings-v1.json");
}

function validateStoredSettings(value: unknown): VersionedGlobalSettings {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("is not a JSON object");
  const record = value as Record<string, unknown>;
  const allowed = new Set(["version", "modelID", "language", "includeFilename"]);
  if (Object.keys(record).some(key => !allowed.has(key))) throw new Error("contains an unknown setting");
  if (record.version !== 1) throw new Error("has an unsupported version");
  if (record.modelID !== undefined) resolveModelName(String(record.modelID));
  if (record.language !== undefined && (typeof record.language !== "string" || !validLanguages.has(record.language))) {
    throw new Error("contains an invalid language");
  }
  if (record.includeFilename !== undefined && typeof record.includeFilename !== "boolean") {
    throw new Error("contains an invalid filename setting");
  }
  return record as unknown as VersionedGlobalSettings;
}

export async function loadGlobalSettings(
  environment: NodeJS.ProcessEnv = process.env
): Promise<VersionedGlobalSettings> {
  const file = settingsFilePath(environment);
  try {
    return validateStoredSettings(JSON.parse(await readFile(file, "utf8")));
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return { version: 1 };
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
    const next: VersionedGlobalSettings = { ...current, ...update, version: 1 };
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
    if (update?.modelID !== undefined) merged.modelID = update.modelID;
    if (update?.language !== undefined) merged.language = update.language;
    if (update?.includeFilename !== undefined) merged.includeFilename = update.includeFilename;
  }
  return merged;
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
  return `WhisperBridge settings (${source}): ${name} [${model.id}] · language ${settings.language} · filename ${filename}`;
}

const markerPattern = new RegExp(
  `^${TRANSCRIPT_MARKER.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\n` +
  "WhisperBridge settings \\((chat|default)\\): [^\\n]* \\[([a-z0-9.-]+)\\] · language ([a-z0-9-]+) · filename (included|omitted)(?:\\n|$)"
);

export function parseSettingsMarker(text: string): ResolvedSpeechSettings | null {
  const match = markerPattern.exec(text);
  if (!match) return null;
  const model = modelByID(match[2]);
  if (!model?.available || !validLanguages.has(match[3])) return null;
  return {
    modelID: model.id,
    language: match[3],
    includeFilename: match[4] === "included",
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
