import assert from "node:assert/strict";
import test from "node:test";
import type { ChatMessage, FileHandle, PromptPreprocessorController } from "@lmstudio/sdk";
import { performance } from "node:perf_hooks";
import { TRANSCRIPT_MARKER } from "../src/constants";
import { createPreprocessor, type PreprocessDependencies } from "../src/preprocess";
import { INHERIT_SETTING } from "../src/settings";

interface MockFile {
  identifier: string;
  name: string;
  sizeBytes: number;
  getFilePath: () => Promise<string>;
}

function file(name: string, identifier = name): MockFile {
  return {
    identifier,
    name,
    sizeBytes: 100,
    getFilePath: async () => `/authorized/${name}`
  };
}

function harness(
  text: string,
  files: MockFile[],
  settings: { model?: string; language?: string; filename?: string } = {},
  historyTexts: string[] = []
) {
  let replacement: string | undefined;
  let consumed: string[] = [];
  let configReads = 0;
  let historyReads = 0;
  const states: unknown[] = [];
  const abortController = new AbortController();
  const message = {
    getText: () => text,
    getFiles: () => files,
    consumeFiles: (_client: unknown, predicate: (candidate: MockFile) => boolean) => {
      const selected = files.filter(predicate);
      consumed = selected.map(item => item.identifier);
      return selected;
    },
    replaceText: (value: string) => { replacement = value; }
  } as unknown as ChatMessage;
  const controller = {
    client: {},
    abortSignal: abortController.signal,
    getPluginConfig: () => {
      configReads += 1;
      return {
        get: (key: string) => {
          if (key === "language") return settings.language ?? INHERIT_SETTING;
          if (key === "model") return settings.model ?? INHERIT_SETTING;
          return settings.filename ?? INHERIT_SETTING;
        }
      };
    },
    pullHistory: async () => {
      historyReads += 1;
      return {
        getMessagesArray: () => historyTexts.map(value => ({
          getRole: () => "user",
          getText: () => value
        }))
      };
    },
    createStatus: () => ({ setState: (state: unknown) => states.push(state) })
  } as unknown as PromptPreprocessorController;
  return {
    message,
    controller,
    abortController,
    replacement: () => replacement,
    consumed: () => consumed,
    configReads: () => configReads,
    historyReads: () => historyReads,
    states
  };
}

function dependencies(overrides: Partial<PreprocessDependencies> = {}): PreprocessDependencies {
  return {
    ensureModel: async () => "/models/whisper-base/revision",
    runHelper: async () => ({ text: "Recognized speech", detectedLanguage: "English" }),
    validateContext: async () => {},
    loadGlobalSettings: async () => ({ version: 1 }),
    saveGlobalSettings: async () => {},
    ...overrides
  };
}

test("text-only prompts take the zero-work bypass", async () => {
  const context = harness("ordinary prompt", []);
  let runtimeCalls = 0;
  let settingsReads = 0;
  const preprocess = createPreprocessor(dependencies({
    ensureModel: async () => { runtimeCalls += 1; return "/model"; },
    loadGlobalSettings: async () => { settingsReads += 1; return { version: 1 }; }
  }));
  const result = await preprocess(context.controller, context.message);
  assert.equal(result, context.message);
  assert.equal(context.configReads(), 0);
  assert.equal(runtimeCalls, 0);
  assert.equal(settingsReads, 0);
  assert.equal(context.historyReads(), 0);
  assert.equal(context.replacement(), undefined);
});

test("a text-only WhisperBridge command is also untouched", async () => {
  const context = harness("/wb default model=best", []);
  let settingsReads = 0;
  const preprocess = createPreprocessor(dependencies({
    loadGlobalSettings: async () => { settingsReads += 1; return { version: 1 }; }
  }));
  await preprocess(context.controller, context.message);
  assert.equal(context.configReads(), 0);
  assert.equal(context.historyReads(), 0);
  assert.equal(settingsReads, 0);
  assert.equal(context.replacement(), undefined);
});

test("text-only bypass adds negligible local processing", async () => {
  const context = harness("ordinary prompt", []);
  const preprocess = createPreprocessor(dependencies());
  const start = performance.now();
  for (let index = 0; index < 10_000; index += 1) {
    await preprocess(context.controller, context.message);
  }
  const duration = performance.now() - start;
  assert.ok(duration < 15, `10,000 bypass calls took ${duration.toFixed(1)} ms`);
});

test("an already transformed message is idempotent", async () => {
  const context = harness(`${TRANSCRIPT_MARKER}\n\nExisting transcript`, [file("meeting.wav")]);
  let modelCalls = 0;
  const preprocess = createPreprocessor(dependencies({
    ensureModel: async () => { modelCalls += 1; return "/model"; }
  }));
  await preprocess(context.controller, context.message);
  assert.equal(modelCalls, 0);
  assert.deepEqual(context.consumed(), []);
  assert.equal(context.replacement(), undefined);
});

test("successful transcription replaces text and consumes only the audio file", async () => {
  const audio = file("meeting.m4a", "audio-id");
  const document = file("notes.pdf", "document-id");
  const context = harness("Summarize this", [audio, document]);
  const preprocess = createPreprocessor(dependencies());
  await preprocess(context.controller, context.message);
  assert.deepEqual(context.consumed(), ["audio-id"]);
  assert.match(context.replacement() ?? "", /Summarize this/);
  assert.match(context.replacement() ?? "", /Recognized speech/);
  assert.ok(context.states.length > 0);
});

test("runtime failure leaves the original message and attachments untouched", async () => {
  const context = harness("Keep this instruction", [file("meeting.wav")]);
  const preprocess = createPreprocessor(dependencies({
    runHelper: async () => { throw new Error("decoder failed"); }
  }));
  await assert.rejects(preprocess(context.controller, context.message), /decoder failed/);
  assert.deepEqual(context.consumed(), []);
  assert.equal(context.replacement(), undefined);
});

test("context overflow leaves the original message and attachment untouched", async () => {
  const context = harness("Keep this instruction", [file("meeting.wav")]);
  const preprocess = createPreprocessor(dependencies({
    validateContext: async () => { throw new Error("does not fit this model's context"); }
  }));
  await assert.rejects(preprocess(context.controller, context.message), /does not fit/);
  assert.deepEqual(context.consumed(), []);
  assert.equal(context.replacement(), undefined);
});

test("multiple audio files fail before model or runtime work", async () => {
  const context = harness("Transcribe", [file("one.wav"), file("two.mp3")]);
  let modelCalls = 0;
  const preprocess = createPreprocessor(dependencies({
    ensureModel: async () => { modelCalls += 1; return "/model"; }
  }));
  await assert.rejects(preprocess(context.controller, context.message), /one audio file/);
  assert.equal(modelCalls, 0);
  assert.deepEqual(context.consumed(), []);
});

test("unsupported language fails before model or helper activity", async () => {
  const context = harness("Transcribe", [file("meeting.wav")], {
    model: "moonshine-tiny-english",
    language: "fr"
  });
  let modelCalls = 0;
  let helperCalls = 0;
  const preprocess = createPreprocessor(dependencies({
    ensureModel: async () => { modelCalls += 1; return "/model"; },
    runHelper: async () => { helperCalls += 1; return { text: "unexpected" }; }
  }));
  await assert.rejects(preprocess(context.controller, context.message), /does not support/);
  assert.equal(modelCalls, 0);
  assert.equal(helperCalls, 0);
  assert.deepEqual(context.consumed(), []);
});

test("a chat directive selects the model and is removed from the outgoing instruction", async () => {
  const context = harness("/wb model=better language=fr filename=off\nSummarize this", [file("meeting.wav")]);
  let selectedModel = "";
  const preprocess = createPreprocessor(dependencies({
    ensureModel: async model => { selectedModel = model.id; return "/model"; }
  }));
  await preprocess(context.controller, context.message);
  assert.equal(selectedModel, "whisper-small-multilingual");
  assert.doesNotMatch(context.replacement() ?? "", /\/wb/);
  assert.match(context.replacement() ?? "", /User request:\nSummarize this/);
  assert.match(context.replacement() ?? "", /WhisperBridge settings \(chat\)/);
  assert.doesNotMatch(context.replacement() ?? "", /from “meeting\.wav”/);
});

test("an invalid directive fails before config, history, settings, model, or helper activity", async () => {
  const context = harness("/wb model=unknown\nTranscribe", [file("meeting.wav")]);
  let settingsReads = 0;
  let modelCalls = 0;
  let helperCalls = 0;
  const preprocess = createPreprocessor(dependencies({
    loadGlobalSettings: async () => { settingsReads += 1; return { version: 1 }; },
    ensureModel: async () => { modelCalls += 1; return "/model"; },
    runHelper: async () => { helperCalls += 1; return { text: "unexpected" }; }
  }));
  await assert.rejects(preprocess(context.controller, context.message), /View README/);
  assert.equal(context.configReads(), 0);
  assert.equal(context.historyReads(), 0);
  assert.equal(settingsReads, 0);
  assert.equal(modelCalls, 0);
  assert.equal(helperCalls, 0);
  assert.deepEqual(context.consumed(), []);
});

test("the latest chat marker selects a model in a later audio prompt", async () => {
  const previous = `${TRANSCRIPT_MARKER}\nWhisperBridge settings (chat): Whisper Small Q5 — Lower-memory multilingual [whisper-small-q5] · language en · filename included`;
  const context = harness("Continue", [file("next.wav")], {}, [previous]);
  let selectedModel = "";
  const preprocess = createPreprocessor(dependencies({
    ensureModel: async model => { selectedModel = model.id; return "/model"; }
  }));
  await preprocess(context.controller, context.message);
  assert.equal(selectedModel, "whisper-small-q5");
  assert.match(context.replacement() ?? "", /language en/);
});

test("a global directive saves only after successful transcription and validation", async () => {
  const context = harness("/wb default model=smallest filename=off\nTranscribe", [file("note.wav")]);
  const saved: unknown[] = [];
  const preprocess = createPreprocessor(dependencies({
    saveGlobalSettings: async update => { saved.push(update); }
  }));
  await preprocess(context.controller, context.message);
  assert.deepEqual(saved, [{ modelID: "whisper-tiny-multilingual", includeFilename: false }]);
  assert.match(context.replacement() ?? "", /settings \(default\)/);

  const failed = harness("/wb default model=best\nTranscribe", [file("bad.wav")]);
  const failedSaves: unknown[] = [];
  const failingPreprocess = createPreprocessor(dependencies({
    validateContext: async () => { throw new Error("does not fit"); },
    saveGlobalSettings: async update => { failedSaves.push(update); }
  }));
  await assert.rejects(failingPreprocess(failed.controller, failed.message), /does not fit/);
  assert.deepEqual(failedSaves, []);
});

test("a global reset is committed after success", async () => {
  const context = harness("/wb default reset\nTranscribe", [file("note.wav")]);
  const saved: unknown[] = [];
  const preprocess = createPreprocessor(dependencies({
    saveGlobalSettings: async update => { saved.push(update); }
  }));
  await preprocess(context.controller, context.message);
  assert.deepEqual(saved, [null]);
});
