import { spawn } from "node:child_process";
import { tool, type Tool } from "@lmstudio/sdk";
import { z } from "zod";
import { resolveHelperPath } from "./helper";
import { dataDirectory } from "./modelStore";

async function libraryRequest(payload: Record<string, unknown>): Promise<string> {
  const executable = await resolveHelperPath();
  return await new Promise<string>((resolve, reject) => {
    const child = spawn(executable, [], { stdio: ["pipe", "pipe", "pipe"] });
    let output = "";
    let diagnostic = "";
    child.stdout.setEncoding("utf8");
    child.stdout.on("data", chunk => { output = (output + String(chunk)).slice(-64_000); });
    child.stderr.setEncoding("utf8");
    child.stderr.on("data", chunk => { diagnostic = (diagnostic + String(chunk)).slice(-4_000); });
    child.on("error", reject);
    child.on("close", code => {
      for (const line of output.split("\n")) {
        if (!line.trim()) continue;
        try {
          const event = JSON.parse(line) as { type: string; text?: string; message?: string };
          if (event.type === "result" && event.text !== undefined) { resolve(event.text); return; }
          if (event.type === "error") { reject(new Error(event.message ?? "Library query failed.")); return; }
        } catch { /* keep looking for the bounded protocol result */ }
      }
      reject(new Error(diagnostic.trim() || `Transcript library helper exited with code ${code}.`));
    });
    child.stdin.end(JSON.stringify({ version: 3, library: { enabled: false, dataDirectory: dataDirectory() }, ...payload }));
  });
}

export async function transcriptTools(): Promise<Tool[]> {
  return [
    tool({
      name: "search_transcripts",
      description: "Search the user's local WhisperBridge transcript library by full text and optional speaker name. Returns bounded snippets and transcript IDs, never audio or file paths.",
      parameters: {
        query: z.string().max(500),
        speaker: z.string().max(100).optional(),
        limit: z.number().int().min(1).max(50).optional()
      },
      implementation: args => libraryRequest({ action: "search_transcripts", ...args })
    }),
    tool({
      name: "get_transcript_excerpt",
      description: "Read a bounded timestamped excerpt from one local WhisperBridge transcript by ID. Returns transcript text and speaker labels, never audio or private paths.",
      parameters: {
        transcriptID: z.string().uuid(),
        start: z.number().min(0).optional(),
        end: z.number().positive().optional(),
        limit: z.number().int().min(1).max(100).optional()
      },
      implementation: args => libraryRequest({ action: "get_transcript_excerpt", ...args })
    })
  ];
}
