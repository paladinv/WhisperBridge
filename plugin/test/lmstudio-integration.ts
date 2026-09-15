import assert from "node:assert/strict";
import { stat } from "node:fs/promises";
import path from "node:path";
import {
  ChatMessage,
  LMStudioClient,
  type PromptPreprocessorController
} from "@lmstudio/sdk";
import { TRANSCRIPT_MARKER } from "../src/constants";
import { runHelper } from "../src/helper";
import { ensureModel } from "../src/modelStore";
import { createPreprocessor } from "../src/preprocess";

const fixturePath = process.env.WHISPERBRIDGE_AUDIO_FIXTURE ??
  path.resolve(process.cwd(), "..", ".build-artifacts", "fixtures", "whisper-smoke-real.wav");
const expectedTranscript = process.env.WHISPERBRIDGE_EXPECTED_TRANSCRIPT ??
  "Whisper Bridge turns audio into text for local models.";

async function main(): Promise<void> {
  const client = new LMStudioClient({
    clientIdentifier: `whisperbridge-headless-qa-${Date.now()}`
  });
  const abortController = new AbortController();
  const statusStates: Array<{ status: string; text: string }> = [];

  try {
    const file = await client.files.prepareFile(fixturePath);
    const lmStudioPath = await file.getFilePath();
    const uploaded = await stat(lmStudioPath);
    assert.ok(uploaded.isFile(), "LM Studio did not provide a readable local file path");
    assert.equal(uploaded.size, file.sizeBytes, "LM Studio file-handle size changed during upload");

    const message = ChatMessage.create("user", "Return the transcript verbatim.");
    message.appendFile(file);
    const controller = {
      client,
      abortSignal: abortController.signal,
      getPluginConfig: () => ({
        get: (key: string) => {
          if (key === "model") return "whisper-base-multilingual";
          if (key === "language") return "en";
          return true;
        }
      }),
      createStatus: (state: { status: string; text: string }) => {
        statusStates.push(state);
        return { setState: (next: { status: string; text: string }) => statusStates.push(next) };
      }
    } as unknown as PromptPreprocessorController;

    const preprocess = createPreprocessor({
      validateContext: async () => {},
      ensureModel,
      runHelper
    });
    const result = await preprocess(controller, message);

    assert.match(result.getText(), new RegExp(TRANSCRIPT_MARKER.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
    assert.match(result.getText(), new RegExp(expectedTranscript.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
    assert.equal(result.getFiles(client).length, 0, "processed audio attachment was not consumed");
    assert.deepEqual(statusStates.at(-1), { status: "done", text: "Audio transcribed locally" });

    process.stdout.write(JSON.stringify({
      result: "pass",
      fileHandleType: file.type,
      uploadedBytes: uploaded.size,
      transcript: expectedTranscript,
      finalStatus: statusStates.at(-1)
    }) + "\n");
  } finally {
    await client[Symbol.asyncDispose]();
  }
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
