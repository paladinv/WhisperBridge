import path from "node:path";
import { AUDIO_EXTENSIONS, MAXIMUM_BYTES, TRANSCRIPT_MARKER } from "./constants";
import { formatSettingsLine, type ResolvedSpeechSettings } from "./settings";
import type { HelperResult } from "./helper";

export interface AudioCandidate {
  name: string;
  sizeBytes: number;
}

export function isSupportedAudio(file: AudioCandidate): boolean {
  const extension = path.extname(file.name).slice(1).toLowerCase();
  return AUDIO_EXTENSIONS.has(extension);
}

export function validateAudio(file: AudioCandidate): void {
  if (!isSupportedAudio(file)) {
    throw new Error("Choose a WAV, MP3, M4A, AAC, or FLAC audio file.");
  }
  if (file.sizeBytes <= 0) {
    throw new Error("The selected audio file is empty.");
  }
  if (file.sizeBytes > MAXIMUM_BYTES) {
    throw new Error("The selected audio file is larger than the 500 MiB limit.");
  }
}

export function safeDisplayName(name: string): string {
  return name.replace(/[\u0000-\u001f\u007f]/g, " ").replace(/\s+/g, " ").trim() || "recording";
}

export function formatPrompt(
  instruction: string,
  transcript: string,
  filename: string,
  settings: ResolvedSpeechSettings
): string {
  const cleanTranscript = transcript.trim();
  if (!cleanTranscript) {
    throw new Error("No speech was detected in the recording.");
  }

  const sections = [`${TRANSCRIPT_MARKER}\n${formatSettingsLine(settings)}`];
  const cleanInstruction = instruction.trim();
  if (cleanInstruction) {
    sections.push(`User request:\n${cleanInstruction}`);
  }
  const source = settings.includeFilename ? ` from “${safeDisplayName(filename)}”` : "";
  sections.push(
    `Audio transcript${source}:\n--- BEGIN WHISPERBRIDGE TRANSCRIPT ---\n${cleanTranscript}\n--- END WHISPERBRIDGE TRANSCRIPT ---`
  );
  return sections.join("\n\n");
}

const fillerPattern = /\b(?:um+|uh+|erm|er)\b[,.]?\s*/gi;

export function formatStructuredTranscript(result: HelperResult, settings: ResolvedSpeechSettings): string {
  if (!result.segments?.length || settings.timestampGranularity === "none") {
    return settings.removeFillers ? result.text.replace(fillerPattern, "").replace(/\s+([,.!?;:])/g, "$1").trim() : result.text;
  }
  return result.segments.map(segment => {
    let text = settings.removeFillers ? segment.text.replace(fillerPattern, "").replace(/\s+([,.!?;:])/g, "$1").trim() : segment.text;
    if (settings.timestampGranularity === "word" && segment.words?.length) {
      text = segment.words.map(word => {
        const value = settings.removeFillers && /^(?:um+|uh+|erm|er)[,.]?$/i.test(word.text.trim()) ? "" : word.text;
        return value && word.start !== undefined && !settings.compact ? `[${formatTime(word.start)}]${value}` : value;
      }).join("").trim();
    }
    const timestamp = !settings.compact && segment.start !== undefined ? `[${formatTime(segment.start)}] ` : "";
    const speaker = segment.speaker ? `${segment.speaker}: ` : "";
    return `${timestamp}${speaker}${text}`.trimEnd();
  }).filter(Boolean).join("\n");
}

function formatTime(seconds: number): string {
  const total = Math.max(0, Math.round(seconds * 1000));
  const hours = Math.floor(total / 3_600_000);
  const minutes = Math.floor(total / 60_000) % 60;
  const secs = Math.floor(total / 1000) % 60;
  const millis = total % 1000;
  return `${String(hours).padStart(2, "0")}:${String(minutes).padStart(2, "0")}:${String(secs).padStart(2, "0")}.${String(millis).padStart(3, "0")}`;
}
