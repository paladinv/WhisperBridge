import assert from "node:assert/strict";
import test from "node:test";
import path from "node:path";
import { performance } from "node:perf_hooks";
import { runHelper } from "../src/helper";
import { MODEL_CATALOG, modelByID, DEFAULT_MODEL_ID } from "../src/modelCatalog";

const model = modelByID(DEFAULT_MODEL_ID)!;

test("exchanges versioned JSON and reports helper progress", async () => {
  const fixture = path.join(__dirname, "fixtures", "fake-helper.mjs");
  const progress: string[] = [];
  const result = await runHelper(
    "/audio.wav",
    model,
    "/models/whisper-base/revision",
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
  const operation = runHelper(
    "/audio.wav",
    model,
    "/models/whisper-base/revision",
    "auto",
    controller.signal,
    () => {},
    fixture
  );
  setTimeout(() => controller.abort(), 25);
  await assert.rejects(operation, /cancelled/);
  assert.ok(performance.now() - start < 2_500);
});

test("sends protocol version 2 contract for every implemented adapter", async () => {
  const fixture = path.join(__dirname, "fixtures", "fake-helper.mjs");
  for (const selected of MODEL_CATALOG.filter(candidate => candidate.engine !== "canaryQwen")) {
    const result = await runHelper(
      "/audio.wav",
      selected,
      `/models/${selected.id}/${selected.revision}`,
      selected.languages[0],
      new AbortController().signal,
      () => {},
      fixture
    );
    assert.equal(result.text, "Fixture transcript", selected.engine);
    if (selected.engine === "moss") {
      assert.deepEqual(result.segments, [
        { start: 0.1, end: 1.2, speaker: "S01", text: "Fixture transcript" }
      ]);
    }
  }
});
