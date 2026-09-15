import assert from "node:assert/strict";
import test from "node:test";
import type { ChatMessage, FileHandle, PromptPreprocessorController } from "@lmstudio/sdk";
import { performance } from "node:perf_hooks";
import { TRANSCRIPT_MARKER } from "../src/constants";
import { createPreprocessor, type PreprocessDependencies } from "../src/preprocess";

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

function harness(text: string, files: MockFile[]) {
  let replacement: string | undefined;
  let consumed: string[] = [];
  let configReads = 0;
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
      return { get: (key: string) => key === "language" ? "auto" : true };
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
    states
  };
}

function dependencies(overrides: Partial<PreprocessDependencies> = {}): PreprocessDependencies {
  return {
    ensureModel: async () => "/models/ggml-base.bin",
    runHelper: async () => ({ text: "Recognized speech", detectedLanguage: "English" }),
    validateContext: async () => {},
    ...overrides
  };
}

test("text-only prompts take the zero-work bypass", async () => {
  const context = harness("ordinary prompt", []);
  let runtimeCalls = 0;
  const preprocess = createPreprocessor(dependencies({
    ensureModel: async () => { runtimeCalls += 1; return "/model"; }
  }));
  const result = await preprocess(context.controller, context.message);
  assert.equal(result, context.message);
  assert.equal(context.configReads(), 0);
  assert.equal(runtimeCalls, 0);
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
  assert.ok(duration < 250, `10,000 bypass calls took ${duration.toFixed(1)} ms`);
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
