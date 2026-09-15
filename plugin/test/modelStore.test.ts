import assert from "node:assert/strict";
import test from "node:test";
import { createHash } from "node:crypto";
import { mkdir, readFile, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import type { ModelDescriptor } from "../src/modelCatalog";
import { dataDirectory, ensureModel, modelDirectory } from "../src/modelStore";

test("uses the explicit data directory for development and tests", () => {
  assert.equal(
    dataDirectory({ WHISPERBRIDGE_DATA_DIR: "./.build-artifacts/plugin-data" }),
    path.resolve("./.build-artifacts/plugin-data")
  );
});

const payload = Buffer.from("verified fixture model");
const fixtureModel: ModelDescriptor = {
  id: "fixture-model",
  displayName: "Fixture",
  engine: "whisperCpp",
  repository: "fixture/model",
  revision: "0123456789abcdef0123456789abcdef01234567",
  license: "MIT",
  attribution: "Fixture",
  languages: ["en"],
  automaticLanguageDetection: false,
  outputStyle: "plain",
  estimatedPeakMemoryBytes: 1,
  minimumMacOS: "14.0",
  available: true,
  entryFile: "model.bin",
  files: [{
    path: "model.bin",
    sizeBytes: payload.length,
    sha256: createHash("sha256").update(payload).digest("hex")
  }]
};

test("downloads once, verifies, shares concurrent work, and repairs corruption", async () => {
  const root = path.resolve("..", ".build-artifacts", "node-model-store-test");
  const environment = { WHISPERBRIDGE_DATA_DIR: root };
  await rm(root, { recursive: true, force: true });
  await mkdir(root, { recursive: true });
  const originalFetch = globalThis.fetch;
  let fetches = 0;
  globalThis.fetch = async () => {
    fetches += 1;
    await new Promise(resolve => setTimeout(resolve, 10));
    return new Response(payload, { headers: { "content-length": String(payload.length) } });
  };
  try {
    const signal = new AbortController().signal;
    const [first, second] = await Promise.all([
      ensureModel(fixtureModel, signal, () => {}, environment),
      ensureModel(fixtureModel, signal, () => {}, environment)
    ]);
    assert.equal(first, second);
    assert.equal(first, modelDirectory(fixtureModel, environment));
    assert.equal(fetches, 1);
    assert.deepEqual(await readFile(path.join(first, "model.bin")), payload);

    await ensureModel(fixtureModel, signal, () => {}, environment);
    assert.equal(fetches, 1);

    await writeFile(path.join(first, "model.bin"), "corrupt");
    await ensureModel(fixtureModel, signal, () => {}, environment);
    assert.equal(fetches, 2);
    assert.deepEqual(await readFile(path.join(first, "model.bin")), payload);
  } finally {
    globalThis.fetch = originalFetch;
  }
});
