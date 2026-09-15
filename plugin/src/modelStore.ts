import { createHash } from "node:crypto";
import { createReadStream, createWriteStream } from "node:fs";
import { mkdir, open, readFile, rename, rm, stat, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { Readable } from "node:stream";
import { pipeline } from "node:stream/promises";
import { MODEL } from "./constants";

interface VerificationRecord {
  sizeBytes: number;
  mtimeMs: number;
  sha256: string;
}

export function dataDirectory(environment: NodeJS.ProcessEnv = process.env): string {
  if (environment.WHISPERBRIDGE_DATA_DIR) {
    return path.resolve(environment.WHISPERBRIDGE_DATA_DIR);
  }
  if (process.platform !== "darwin") {
    throw new Error("WhisperBridge currently supports macOS on Apple silicon.");
  }
  return path.join(os.homedir(), "Library", "Application Support", "LM Studio", "WhisperBridge");
}

async function sha256(filePath: string, signal: AbortSignal): Promise<string> {
  const hash = createHash("sha256");
  for await (const chunk of createReadStream(filePath, { signal })) {
    hash.update(chunk as Buffer);
  }
  return hash.digest("hex");
}

async function readVerification(recordPath: string): Promise<VerificationRecord | null> {
  try {
    return JSON.parse(await readFile(recordPath, "utf8")) as VerificationRecord;
  } catch {
    return null;
  }
}

async function verifiedModel(modelPath: string, recordPath: string, signal: AbortSignal): Promise<boolean> {
  try {
    const modelStat = await stat(modelPath);
    if (!modelStat.isFile() || modelStat.size !== MODEL.sizeBytes) return false;
    const record = await readVerification(recordPath);
    if (
      record?.sizeBytes === modelStat.size &&
      record.mtimeMs === modelStat.mtimeMs &&
      record.sha256 === MODEL.sha256
    ) {
      return true;
    }
    const digest = await sha256(modelPath, signal);
    if (digest !== MODEL.sha256) return false;
    await writeFile(
      recordPath,
      JSON.stringify({ sizeBytes: modelStat.size, mtimeMs: modelStat.mtimeMs, sha256: digest }),
      { encoding: "utf8", mode: 0o600 }
    );
    return true;
  } catch (error) {
    if (signal.aborted) throw error;
    return false;
  }
}

export async function ensureModel(
  signal: AbortSignal,
  onProgress: (fraction: number) => void,
  environment: NodeJS.ProcessEnv = process.env
): Promise<string> {
  const directory = dataDirectory(environment);
  const modelPath = path.join(directory, MODEL.filename);
  const partialPath = `${modelPath}.partial`;
  const recordPath = `${modelPath}.verified.json`;
  await mkdir(directory, { recursive: true, mode: 0o700 });

  if (await verifiedModel(modelPath, recordPath, signal)) return modelPath;
  await rm(partialPath, { force: true });
  await rm(recordPath, { force: true });

  const response = await fetch(MODEL.url, { signal, redirect: "follow" });
  if (!response.ok || !response.body) {
    throw new Error(`The speech model download failed (HTTP ${response.status}).`);
  }
  const contentLength = Number(response.headers.get("content-length"));
  if (Number.isFinite(contentLength) && contentLength !== MODEL.sizeBytes) {
    throw new Error("The speech model download had an unexpected size.");
  }

  let received = 0;
  const source = Readable.fromWeb(response.body as never);
  source.on("data", chunk => {
    received += (chunk as Buffer).length;
    onProgress(Math.min(received / MODEL.sizeBytes, 0.99));
  });
  try {
    await pipeline(source, createWriteStream(partialPath, { mode: 0o600 }), { signal });
    const partialStat = await stat(partialPath);
    if (partialStat.size !== MODEL.sizeBytes || (await sha256(partialPath, signal)) !== MODEL.sha256) {
      throw new Error("The speech model did not pass integrity verification.");
    }
    await rm(modelPath, { force: true });
    await rename(partialPath, modelPath);
    const modelStat = await stat(modelPath);
    await writeFile(
      recordPath,
      JSON.stringify({ sizeBytes: modelStat.size, mtimeMs: modelStat.mtimeMs, sha256: MODEL.sha256 }),
      { encoding: "utf8", mode: 0o600 }
    );
    const handle = await open(modelPath, "r");
    await handle.close();
    onProgress(1);
    return modelPath;
  } catch (error) {
    await rm(partialPath, { force: true });
    throw error;
  }
}
