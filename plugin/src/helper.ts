import { spawn } from "node:child_process";
import { access } from "node:fs/promises";
import path from "node:path";

export interface HelperProgress {
  stage: "validating" | "decoding" | "transcribing";
  fraction?: number;
}

interface HelperEvent {
  type: "stage" | "progress" | "result" | "error";
  stage?: HelperProgress["stage"];
  progress?: number;
  text?: string;
  detectedLanguage?: string;
  code?: string;
  message?: string;
}

export interface HelperResult {
  text: string;
  detectedLanguage?: string;
}

export async function resolveHelperPath(environment: NodeJS.ProcessEnv = process.env): Promise<string> {
  const candidates = [
    environment.WHISPERBRIDGE_HELPER_PATH,
    path.resolve(process.cwd(), "native", "macos-arm64", "WhisperBridgeCLI"),
    path.resolve(__dirname, "..", "native", "macos-arm64", "WhisperBridgeCLI"),
    path.resolve(__dirname, "..", "..", "native", "macos-arm64", "WhisperBridgeCLI")
  ].filter((candidate): candidate is string => Boolean(candidate));

  for (const candidate of candidates) {
    try {
      await access(candidate);
      return candidate;
    } catch {
      // Try the next location because LM Studio may compile the plugin into a staging directory.
    }
  }
  throw new Error("The WhisperBridge transcription helper is missing. Reinstall the plugin.");
}

export async function runHelper(
  audioPath: string,
  modelPath: string,
  language: string,
  signal: AbortSignal,
  onProgress: (progress: HelperProgress) => void,
  helperPath?: string
): Promise<HelperResult> {
  const executable = helperPath ?? (await resolveHelperPath());
  return await new Promise<HelperResult>((resolve, reject) => {
    const child = spawn(executable, [], { stdio: ["pipe", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    let result: HelperResult | undefined;
    let helperError: Error | undefined;
    let settled = false;
    let forceKillTimer: NodeJS.Timeout | undefined;

    const finish = (error?: Error) => {
      if (settled) return;
      settled = true;
      if (forceKillTimer) clearTimeout(forceKillTimer);
      signal.removeEventListener("abort", abort);
      if (error) reject(error);
      else if (result) resolve(result);
      else reject(helperError ?? new Error("The transcription helper returned no result."));
    };
    const processLine = (line: string) => {
      if (!line.trim()) return;
      let event: HelperEvent;
      try {
        event = JSON.parse(line) as HelperEvent;
      } catch {
        helperError = new Error("The transcription helper returned an invalid response.");
        return;
      }
      if (event.type === "stage" && event.stage) onProgress({ stage: event.stage });
      if (event.type === "progress" && event.stage) {
        onProgress({ stage: event.stage, fraction: event.progress });
      }
      if (event.type === "result" && event.text) {
        result = { text: event.text, detectedLanguage: event.detectedLanguage };
      }
      if (event.type === "error") {
        helperError = new Error(event.message || "Transcription failed.");
      }
    };
    const abort = () => {
      helperError = new Error("Transcription was cancelled.");
      child.kill("SIGTERM");
      forceKillTimer = setTimeout(() => child.kill("SIGKILL"), 2_000);
      forceKillTimer.unref();
    };

    signal.addEventListener("abort", abort, { once: true });
    child.stdout.setEncoding("utf8");
    child.stdout.on("data", chunk => {
      stdout += chunk;
      const lines = stdout.split("\n");
      stdout = lines.pop() ?? "";
      for (const line of lines) processLine(line);
    });
    child.stderr.setEncoding("utf8");
    child.stderr.on("data", chunk => {
      const remaining = Math.max(0, 4096 - stderr.length);
      if (remaining > 0) stderr += String(chunk).slice(0, remaining);
    });
    child.on("error", error => finish(error));
    child.on("close", code => {
      processLine(stdout);
      if (code === 0) finish();
      else finish(helperError ?? new Error(stderr.trim() || `The transcription helper exited with code ${code}.`));
    });
    child.stdin.end(JSON.stringify({ version: 1, audioPath, modelPath, language }));
    if (signal.aborted) abort();
  });
}
