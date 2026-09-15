import assert from "node:assert/strict";
import test from "node:test";
import path from "node:path";
import { performance } from "node:perf_hooks";
import { runHelper } from "../src/helper";

test("exchanges versioned JSON and reports helper progress", async () => {
  const fixture = path.join(__dirname, "fixtures", "fake-helper.mjs");
  const progress: string[] = [];
  const result = await runHelper(
    "/audio.wav",
    "/model.bin",
    "auto",
    new AbortController().signal,
    update => progress.push(update.stage),
    fixture
  );
  assert.deepEqual(result, { text: "Fixture transcript", detectedLanguage: "English" });
  assert.deepEqual(progress, ["transcribing"]);
});

test("cancellation terminates a running helper promptly", async () => {
  const fixture = path.join(__dirname, "fixtures", "slow-helper.mjs");
  const controller = new AbortController();
  const start = performance.now();
  const operation = runHelper("/audio.wav", "/model.bin", "auto", controller.signal, () => {}, fixture);
  setTimeout(() => controller.abort(), 25);
  await assert.rejects(operation, /cancelled/);
  assert.ok(performance.now() - start < 2_500);
});
