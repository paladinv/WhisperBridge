import assert from "node:assert/strict";
import path from "node:path";
import { performance } from "node:perf_hooks";
import { runHelper } from "../src/helper";
import { modelByID, modelDownloadBytes } from "../src/modelCatalog";
import { ensureModel } from "../src/modelStore";

function words(value: string): string[] {
  return value
    .toLocaleLowerCase()
    .normalize("NFKD")
    .replace(/whisper\s+bridge/gu, "whisperbridge")
    .replace(/[^\p{L}\p{N}\s]/gu, " ")
    .trim()
    .split(/\s+/)
    .filter(Boolean);
}

function wordErrorRate(expected: string, actual: string): number {
  const reference = words(expected);
  const hypothesis = words(actual);
  const rows = Array.from({ length: reference.length + 1 }, () => new Array<number>(hypothesis.length + 1).fill(0));
  for (let row = 0; row <= reference.length; row += 1) rows[row][0] = row;
  for (let column = 0; column <= hypothesis.length; column += 1) rows[0][column] = column;
  for (let row = 1; row <= reference.length; row += 1) {
    for (let column = 1; column <= hypothesis.length; column += 1) {
      rows[row][column] = Math.min(
        rows[row - 1][column] + 1,
        rows[row][column - 1] + 1,
        rows[row - 1][column - 1] + (reference[row - 1] === hypothesis[column - 1] ? 0 : 1)
      );
    }
  }
  return reference.length === 0 ? Number(hypothesis.length > 0) : rows[reference.length][hypothesis.length] / reference.length;
}

async function main(): Promise<void> {
  const [modelID, fixtureArgument, expected, language = "en", audioSecondsArgument = "3.1", mode = "quality"] = process.argv.slice(2);
  assert.ok(modelID && fixtureArgument && expected, "usage: model-smoke <model-id> <fixture> <expected> [language]");
  const model = modelByID(modelID);
  assert.ok(model?.available, `model is not selectable: ${modelID}`);

  const root = path.resolve(process.cwd(), "..", ".build-artifacts", "model-smoke");
  const helper = path.resolve(process.cwd(), "..", ".build-artifacts", "DerivedData", "Build", "Products", "Release", "WhisperBridgeCLI");
  const fixture = path.resolve(fixtureArgument);
  const controller = new AbortController();
  const progress: number[] = [];
  const modelDirectory = await ensureModel(model, controller.signal, value => progress.push(value), {
    ...process.env,
    WHISPERBRIDGE_DATA_DIR: root
  });
  const started = performance.now();
  const result = await runHelper(fixture, model, modelDirectory, language, controller.signal, () => {}, helper);
  const runtimeSeconds = (performance.now() - started) / 1_000;
  const wer = wordErrorRate(expected, result.text);
  const audioSeconds = Number(audioSecondsArgument);
  assert.ok(Number.isFinite(audioSeconds) && audioSeconds > 0, "audio duration must be a positive number");
  const maximumWER = language === "en" ? 0.2 : 0.25;
  const report = {
    modelID,
    engine: model.engine,
    language,
    expected,
    transcript: result.text,
    wordErrorRate: wer,
    qualityGatePassed: wer <= maximumWER,
    runtimeSeconds,
    audioSeconds,
    fasterThanRealTime: runtimeSeconds < audioSeconds,
    downloadBytes: modelDownloadBytes(model),
    downloaded: progress.length > 0,
    segments: result.segments ?? []
  };
  process.stdout.write(JSON.stringify(report, null, 2) + "\n");
  if (mode !== "performance-only") {
    assert.ok(report.qualityGatePassed, `WER ${wer.toFixed(3)} exceeded the release gate: ${result.text}`);
  }
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
