import path from "node:path";
import { AUDIO_EXTENSIONS, MAXIMUM_BYTES, TRANSCRIPT_MARKER } from "./constants";
import { formatSettingsLine, type ResolvedSpeechSettings } from "./settings";

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
