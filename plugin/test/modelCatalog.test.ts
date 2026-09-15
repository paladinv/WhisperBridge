import assert from "node:assert/strict";
import test from "node:test";
import {
  AVAILABLE_MODELS,
  DEFAULT_MODEL_ID,
  MODEL_CATALOG,
  modelByID,
  modelDownloadBytes,
  modelFileURL,
  supportsLanguage
} from "../src/modelCatalog";

test("catalog has unique stable identifiers and complete pinned manifests", () => {
  assert.equal(new Set(MODEL_CATALOG.map(model => model.id)).size, MODEL_CATALOG.length);
  assert.ok(modelByID(DEFAULT_MODEL_ID)?.available);
  for (const model of MODEL_CATALOG.filter(candidate => candidate.engine !== "canaryQwen")) {
    assert.match(model.revision, /^[a-f0-9]{40}$/);
    assert.ok(model.files.length > 0);
    assert.ok(model.license.length > 0);
    assert.ok(model.attribution.length > 0);
    assert.ok(modelDownloadBytes(model) > 0);
    for (const file of model.files) {
      assert.ok(file.sizeBytes > 0);
      assert.match(file.sha256, /^[a-f0-9]{64}$/);
      assert.match(modelFileURL(model, file), new RegExp(model.revision));
    }
  }
});

test("only verified native models are selectable", () => {
  const canary = modelByID("canary-qwen-2.5b");
  assert.equal(canary?.available, false);
  assert.ok(canary?.unavailableReason);
  assert.ok(!AVAILABLE_MODELS.some(model => model.id === canary?.id));
  const moss = modelByID("moss-transcribe-diarize-0.9b-mlx-5bit");
  assert.equal(moss?.available, false);
  assert.match(moss?.unavailableReason ?? "", /VQ-adaptor/);
  assert.ok(!AVAILABLE_MODELS.some(model => model.id === moss?.id));
});

test("offers every official whisper.cpp checkpoint larger than Base", () => {
  const expectedFiles = [
    "ggml-small-q5_1.bin", "ggml-small-q8_0.bin", "ggml-small.bin",
    "ggml-small.en-q5_1.bin", "ggml-small.en-q8_0.bin", "ggml-small.en.bin",
    "ggml-medium-q5_0.bin", "ggml-medium-q8_0.bin", "ggml-medium.bin",
    "ggml-medium.en-q5_0.bin", "ggml-medium.en-q8_0.bin", "ggml-medium.en.bin",
    "ggml-large-v1.bin", "ggml-large-v2-q5_0.bin", "ggml-large-v2-q8_0.bin",
    "ggml-large-v2.bin", "ggml-large-v3-q5_0.bin", "ggml-large-v3.bin",
    "ggml-large-v3-turbo-q5_0.bin", "ggml-large-v3-turbo-q8_0.bin", "ggml-large-v3-turbo.bin"
  ];
  const selectableFiles = AVAILABLE_MODELS
    .filter(model => model.engine === "whisperCpp")
    .flatMap(model => model.files.map(file => file.path));
  for (const expected of expectedFiles) assert.ok(selectableFiles.includes(expected), expected);
});

test("model-specific language compatibility is enforced", () => {
  const moonshine = modelByID("moonshine-tiny-english")!;
  const granite = modelByID("granite-4.0-1b-speech-mlx-5bit")!;
  assert.equal(supportsLanguage(moonshine, "auto"), true);
  assert.equal(supportsLanguage(moonshine, "en"), true);
  assert.equal(supportsLanguage(moonshine, "fr"), false);
  assert.equal(supportsLanguage(granite, "ja"), true);
  assert.equal(supportsLanguage(granite, "zh"), false);
});
