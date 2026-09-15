import { createHash, randomUUID } from "node:crypto";
import { createReadStream, createWriteStream } from "node:fs";
import { mkdir, readFile, rename, rm, stat, statfs, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { Readable } from "node:stream";
import { pipeline } from "node:stream/promises";
import {
  DEFAULT_MODEL_ID,
  modelDownloadBytes,
  modelFileURL,
  type ModelDescriptor,
  type ModelFileDescriptor
} from "./modelCatalog";

interface VerifiedFile {
  path: string;
  sizeBytes: number;
  mtimeMs: number;
  sha256: string;
}

interface VerificationRecord {
  modelID: string;
  repository: string;
  revision: string;
  files: VerifiedFile[];
}

interface DownloadJob {
  controller: AbortController;
  promise: Promise<string>;
  waiters: number;
  progressListeners: Set<(fraction: number) => void>;
}

const downloads = new Map<string, DownloadJob>();
const minimumDownloadHeadroom = 64 * 1_048_576;

export function dataDirectory(environment: NodeJS.ProcessEnv = process.env): string {
  if (environment.WHISPERBRIDGE_DATA_DIR) return path.resolve(environment.WHISPERBRIDGE_DATA_DIR);
  if (process.platform !== "darwin") {
    throw new Error("WhisperBridge currently supports macOS on Apple silicon.");
  }
  return path.join(os.homedir(), "Library", "Application Support", "LM Studio", "WhisperBridge");
}

export function modelDirectory(model: ModelDescriptor, environment: NodeJS.ProcessEnv = process.env): string {
  return path.join(dataDirectory(environment), "models", model.id, model.revision);
}

export function modelPayloadDirectory(model: ModelDescriptor, root: string): string {
  if (model.engine === "whisperCpp") return root;
  return path.join(root, "mlx-audio", model.repository.replaceAll("/", "_"));
}

function assertSafeDescriptor(model: ModelDescriptor): void {
  if (!/^[a-z0-9][a-z0-9.-]*$/.test(model.id)) throw new Error("The speech model has an invalid identifier.");
  if (!/^[a-f0-9]{40}$/.test(model.revision)) {
    throw new Error("The speech model is not pinned to an immutable revision.");
  }
  for (const file of model.files) {
    if (path.isAbsolute(file.path) || file.path.split("/").some(component => component === ".." || component === "")) {
      throw new Error("The speech model manifest contains an unsafe file path.");
    }
    if (file.sizeBytes <= 0 || !/^[a-f0-9]{64}$/.test(file.sha256)) {
      throw new Error("The speech model manifest is incomplete.");
    }
  }
}

async function sha256(filePath: string, signal: AbortSignal): Promise<string> {
  const hash = createHash("sha256");
  for await (const chunk of createReadStream(filePath, { signal })) hash.update(chunk as Buffer);
  return hash.digest("hex");
}

async function readVerification(recordPath: string): Promise<VerificationRecord | null> {
  try {
    return JSON.parse(await readFile(recordPath, "utf8")) as VerificationRecord;
  } catch {
    return null;
  }
}

async function writeVerification(model: ModelDescriptor, root: string, files: VerifiedFile[]): Promise<void> {
  const record: VerificationRecord = {
    modelID: model.id,
    repository: model.repository,
    revision: model.revision,
    files
  };
  await writeFile(path.join(root, "verification.json"), JSON.stringify(record), { encoding: "utf8", mode: 0o600 });
}

async function verifiedModel(model: ModelDescriptor, root: string, signal: AbortSignal): Promise<boolean> {
  const payload = modelPayloadDirectory(model, root);
  const record = await readVerification(path.join(root, "verification.json"));
  if (record?.modelID !== model.id || record.repository !== model.repository || record.revision !== model.revision) {
    return false;
  }
  const verifiedFiles: VerifiedFile[] = [];
  let changed = record.files.length !== model.files.length;
  try {
    for (const file of model.files) {
      const filePath = path.join(payload, file.path);
      const fileStat = await stat(filePath);
      if (!fileStat.isFile() || fileStat.size !== file.sizeBytes) return false;
      const cached = record.files.find(candidate => candidate.path === file.path);
      const digest = cached?.sizeBytes === fileStat.size && cached.mtimeMs === fileStat.mtimeMs && cached.sha256 === file.sha256
        ? cached.sha256
        : await sha256(filePath, signal);
      if (digest !== file.sha256) return false;
      changed ||= cached?.mtimeMs !== fileStat.mtimeMs;
      verifiedFiles.push({ path: file.path, sizeBytes: fileStat.size, mtimeMs: fileStat.mtimeMs, sha256: digest });
    }
    if (changed) await writeVerification(model, root, verifiedFiles);
    return true;
  } catch (error) {
    if (signal.aborted) throw error;
    return false;
  }
}

async function verifyStagedFile(filePath: string, file: ModelFileDescriptor, signal: AbortSignal): Promise<VerifiedFile> {
  const fileStat = await stat(filePath);
  if (!fileStat.isFile() || fileStat.size !== file.sizeBytes || await sha256(filePath, signal) !== file.sha256) {
    throw new Error(`The downloaded speech model file '${file.path}' did not pass integrity verification.`);
  }
  return { path: file.path, sizeBytes: fileStat.size, mtimeMs: fileStat.mtimeMs, sha256: file.sha256 };
}

async function assertDiskSpace(parent: string, model: ModelDescriptor): Promise<void> {
  const volume = await statfs(parent);
  const freeBytes = Number(volume.bavail) * Number(volume.bsize);
  const downloadBytes = modelDownloadBytes(model);
  const requiredBytes = downloadBytes + Math.max(minimumDownloadHeadroom, Math.ceil(downloadBytes * 0.1));
  if (freeBytes < requiredBytes) {
    const required = new Intl.NumberFormat("en", { style: "unit", unit: "megabyte", maximumFractionDigits: 0 })
      .format(requiredBytes / 1_000_000);
    throw new Error(`Not enough free storage for ${model.displayName}. Free at least ${required}.`);
  }
}

async function downloadModel(
  model: ModelDescriptor,
  finalRoot: string,
  signal: AbortSignal,
  progress: (fraction: number) => void
): Promise<string> {
  const parent = path.dirname(finalRoot);
  await mkdir(parent, { recursive: true, mode: 0o700 });
  await assertDiskSpace(parent, model);
  const stagingRoot = path.join(parent, `${model.revision}.partial-${randomUUID()}`);
  const payload = modelPayloadDirectory(model, stagingRoot);
  const totalBytes = modelDownloadBytes(model);
  let completedBytes = 0;
  try {
    await mkdir(payload, { recursive: true, mode: 0o700 });
    const verifiedFiles: VerifiedFile[] = [];
    for (const file of model.files) {
      const destination = path.join(payload, file.path);
      await mkdir(path.dirname(destination), { recursive: true, mode: 0o700 });
      const response = await fetch(modelFileURL(model, file), { signal, redirect: "follow" });
      if (!response.ok || !response.body) {
        throw new Error(`The speech model download failed for '${file.path}' (HTTP ${response.status}).`);
      }
      let fileBytes = 0;
      const source = Readable.fromWeb(response.body as never);
      source.on("data", chunk => {
        fileBytes += (chunk as Buffer).length;
        progress(Math.min((completedBytes + fileBytes) / totalBytes, 0.99));
      });
      await pipeline(source, createWriteStream(destination, { mode: 0o600 }), { signal });
      verifiedFiles.push(await verifyStagedFile(destination, file, signal));
      completedBytes += file.sizeBytes;
    }
    await writeVerification(model, stagingRoot, verifiedFiles);
    await rm(finalRoot, { recursive: true, force: true });
    await rename(stagingRoot, finalRoot);
    progress(1);
    return finalRoot;
  } catch (error) {
    await rm(stagingRoot, { recursive: true, force: true });
    throw error;
  }
}

async function migrateLegacyBaseModel(
  model: ModelDescriptor,
  finalRoot: string,
  signal: AbortSignal,
  environment: NodeJS.ProcessEnv
): Promise<boolean> {
  if (model.id !== DEFAULT_MODEL_ID || model.files.length !== 1) return false;
  const legacyPath = path.join(dataDirectory(environment), "ggml-base.bin");
  try {
    const file = model.files[0];
    const legacyStat = await stat(legacyPath);
    if (legacyStat.size !== file.sizeBytes || await sha256(legacyPath, signal) !== file.sha256) return false;
    const destination = path.join(modelPayloadDirectory(model, finalRoot), file.path);
    await mkdir(path.dirname(destination), { recursive: true, mode: 0o700 });
    await rename(legacyPath, destination);
    const migratedStat = await stat(destination);
    await writeVerification(model, finalRoot, [{
      path: file.path,
      sizeBytes: migratedStat.size,
      mtimeMs: migratedStat.mtimeMs,
      sha256: file.sha256
    }]);
    await rm(`${legacyPath}.verified.json`, { force: true });
    return true;
  } catch (error) {
    if (signal.aborted) throw error;
    return false;
  }
}

function waitForJob(job: DownloadJob, signal: AbortSignal, onProgress: (fraction: number) => void): Promise<string> {
  job.waiters += 1;
  job.progressListeners.add(onProgress);
  return new Promise<string>((resolve, reject) => {
    let finished = false;
    const cleanup = () => {
      if (finished) return;
      finished = true;
      signal.removeEventListener("abort", abort);
      job.progressListeners.delete(onProgress);
      job.waiters -= 1;
      if (job.waiters === 0) job.controller.abort();
    };
    const abort = () => {
      cleanup();
      reject(new Error("Transcription was cancelled."));
    };
    signal.addEventListener("abort", abort, { once: true });
    job.promise.then(
      value => { cleanup(); resolve(value); },
      error => { cleanup(); reject(error); }
    );
    if (signal.aborted) abort();
  });
}

export async function ensureModel(
  model: ModelDescriptor,
  signal: AbortSignal,
  onProgress: (fraction: number) => void,
  environment: NodeJS.ProcessEnv = process.env
): Promise<string> {
  assertSafeDescriptor(model);
  if (!model.available) throw new Error(model.unavailableReason ?? "The selected speech model is unavailable.");
  const finalRoot = modelDirectory(model, environment);
  await mkdir(path.dirname(finalRoot), { recursive: true, mode: 0o700 });
  if (await verifiedModel(model, finalRoot, signal)) return finalRoot;
  if (await migrateLegacyBaseModel(model, finalRoot, signal, environment)) return finalRoot;

  const key = `${finalRoot}:${model.revision}`;
  let job = downloads.get(key);
  if (!job) {
    const controller = new AbortController();
    const progressListeners = new Set<(fraction: number) => void>();
    const created: DownloadJob = { controller, promise: Promise.resolve(finalRoot), waiters: 0, progressListeners };
    created.promise = downloadModel(model, finalRoot, controller.signal, fraction => {
      for (const listener of progressListeners) listener(fraction);
    }).finally(() => downloads.delete(key));
    downloads.set(key, created);
    job = created;
  }
  return await waitForJob(job, signal, onProgress);
}
