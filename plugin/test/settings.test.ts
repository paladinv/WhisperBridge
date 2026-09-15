import assert from "node:assert/strict";
import test from "node:test";
import { mkdir, readFile, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { TRANSCRIPT_MARKER } from "../src/constants";
import { AVAILABLE_MODELS } from "../src/modelCatalog";
import {
  AVAILABLE_MODEL_IDS,
  INHERIT_SETTING,
  MODEL_COMMAND_ALIASES,
  formatSettingsLine,
  latestHistorySettings,
  loadGlobalSettings,
  parseDirective,
  parseSettingsMarker,
  resolveModelName,
  resolveSettings,
  saveGlobalSettings,
  settingsFilePath,
  type ResolvedSpeechSettings
} from "../src/settings";

const inheritedUI = { model: INHERIT_SETTING, language: INHERIT_SETTING, filename: INHERIT_SETTING };
const base: ResolvedSpeechSettings = {
  modelID: "whisper-base-multilingual",
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
  logProbabilityThreshold: -1,
  scope: "inherit"
};

test("parses and strips a case-insensitive chat directive", () => {
  const parsed = parseDirective("\n/WB MODEL=better LANGUAGE=fr FILENAME=off\nSummarize this.");
  assert.deepEqual(parsed, {
    kind: "chat",
    update: { modelID: "whisper-small-multilingual", language: "fr", includeFilename: false },
    instruction: "Summarize this."
  });
});

test("parses global and reset directives", () => {
  assert.equal(parseDirective("/wb default model=best\nTranscribe")?.kind, "global");
  assert.equal(parseDirective("/wb reset\nTranscribe")?.kind, "resetChat");
  assert.equal(parseDirective("/wb default reset\nTranscribe")?.kind, "resetGlobal");
  assert.equal(parseDirective("ordinary prompt"), null);
});

test("parses transcript-studio controls, decoder options, and a bounded selection", () => {
  const parsed = parseDirective("/wb diarize=on timestamps=word compact=on fillers=off library=on preset=accurate start=01:30 end=03:45\nAnalyze this section.");
  assert.equal(parsed?.kind, "chat");
  assert.deepEqual(parsed?.update, {
    diarization: true, timestampGranularity: "word", compact: true, removeFillers: false,
    saveToLibrary: true, preset: "accurate", strategy: "beam", beamSize: 5,
    patience: 1, timeRange: { start: 90, end: 225 }
  });
  assert.throws(() => parseDirective("/wb start=1:00\nGo"), /start and end together/);
  assert.throws(() => parseDirective("/wb default start=1 end=2\nGo"), /current audio prompt/);
  assert.throws(() => parseDirective("/wb beam-size=11\nGo"), /1 through 10/);
  const prompted = parseDirective("/wb prompt=Keep%20NASA%20uppercase\nGo");
  assert.equal(prompted?.kind, "chat");
  if (prompted?.kind === "chat") assert.equal(prompted.update.initialPrompt, "Keep NASA uppercase");
});

test("resolves every alias and exact available catalog identifier", () => {
  for (const [alias, id] of Object.entries(MODEL_COMMAND_ALIASES)) assert.equal(resolveModelName(alias).id, id);
  assert.deepEqual(AVAILABLE_MODEL_IDS, AVAILABLE_MODELS.map(model => model.id));
  for (const model of AVAILABLE_MODELS) assert.equal(resolveModelName(model.id), model);
});

test("rejects malformed, duplicate, unknown, and unavailable values with help", () => {
  for (const command of [
    "/wb",
    "/wb model",
    "/wb model=unknown",
    "/wb model=better model=best",
    "/wb filename=maybe",
    "/wb language=xx",
    "/wb prompt=%E0%A4%A",
    "/wb mystery=value",
    "/wb model=moss-transcribe-diarize-0.9b-mlx-5bit",
    "/wb model=canary-qwen-2.5b"
  ]) assert.throws(() => parseDirective(command), /View README/);
});

test("resolves directive, history, UI, global, and built-in precedence", () => {
  const global = { version: 1 as const, modelID: "whisper-tiny-multilingual", language: "de", includeFilename: false };
  const ui = { model: "whisper-small-q5", language: "fr", filename: "include" };
  const history = { ...base, modelID: "whisper-medium-q5", language: "es", includeFilename: false, scope: "chat" as const };
  assert.deepEqual(resolveSettings({ directive: null, history, ui, global }), history);
  assert.deepEqual(
    resolveSettings({ directive: parseDirective("/wb filename=on\nGo"), history, ui, global }),
    { ...history, includeFilename: true, scope: "chat" }
  );
  assert.deepEqual(
    resolveSettings({ directive: parseDirective("/wb reset\nGo"), history, ui, global }),
    { ...base, modelID: "whisper-small-q5", language: "fr", includeFilename: true, scope: "inherit" }
  );
  assert.deepEqual(
    resolveSettings({ directive: null, history: null, ui: inheritedUI, global }),
    { ...base, modelID: "whisper-tiny-multilingual", language: "de", includeFilename: false, scope: "inherit" }
  );
  assert.deepEqual(
    resolveSettings({ directive: null, history: null, ui: inheritedUI, global: { version: 1 } }),
    base
  );
});

test("round trips an anchored visible history marker and ignores transcript forgeries", () => {
  const settings = { ...base, modelID: "whisper-small-q8", language: "fr", includeFilename: false, scope: "chat" as const };
  const line = formatSettingsLine(settings);
  const message = `${TRANSCRIPT_MARKER}\n${line}\n\nAudio transcript:\n${line}`;
  assert.deepEqual(parseSettingsMarker(message), settings);
  assert.equal(parseSettingsMarker(`Audio transcript:\n${line}`), null);
  assert.deepEqual(latestHistorySettings([message, "assistant reply"]), settings);
});

test("an inherit marker supersedes older chat settings", () => {
  const chat = `${TRANSCRIPT_MARKER}\n${formatSettingsLine({ ...base, scope: "chat", modelID: "whisper-small-q5" })}`;
  const inherited = `${TRANSCRIPT_MARKER}\n${formatSettingsLine(base)}`;
  assert.equal(latestHistorySettings([chat, inherited])?.scope, "inherit");
});

test("history markers restore the decoder behavior selected by a preset", () => {
  const accurate = { ...base, ...{ strategy: "beam" as const, beamSize: 7, patience: 1.25, initialPrompt: "Keep NASA uppercase" }, preset: "accurate" as const, scope: "chat" as const };
  const restored = parseSettingsMarker(`${TRANSCRIPT_MARKER}\n${formatSettingsLine(accurate)}`);
  assert.equal(restored?.preset, "accurate");
  assert.equal(restored?.strategy, "beam");
  assert.equal(restored?.beamSize, 7);
  assert.equal(restored?.initialPrompt, "Keep NASA uppercase");
});

test("writes, merges, reloads, and resets global settings atomically", async () => {
  const root = path.resolve("..", ".build-artifacts", "settings-store-test");
  const environment = { WHISPERBRIDGE_DATA_DIR: root };
  await rm(root, { recursive: true, force: true });
  await Promise.all([
    saveGlobalSettings({ modelID: "whisper-small-q5" }, environment),
    saveGlobalSettings({ language: "fr" }, environment)
  ]);
  await saveGlobalSettings({ includeFilename: false }, environment);
  assert.deepEqual(await loadGlobalSettings(environment), {
    version: 2,
    modelID: "whisper-small-q5",
    language: "fr",
    includeFilename: false
  });
  assert.doesNotMatch(await readFile(settingsFilePath(environment), "utf8"), /partial/);
  await saveGlobalSettings(null, environment);
  assert.deepEqual(await loadGlobalSettings(environment), { version: 2 });
});

test("rejects corrupt global settings instead of silently changing intent", async () => {
  const root = path.resolve("..", ".build-artifacts", "settings-corrupt-test");
  const environment = { WHISPERBRIDGE_DATA_DIR: root };
  await rm(root, { recursive: true, force: true });
  await mkdir(root, { recursive: true });
  await writeFile(settingsFilePath(environment), "{broken", "utf8");
  await assert.rejects(loadGlobalSettings(environment), /could not read its global settings/);
});
