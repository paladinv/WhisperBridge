export const AUDIO_EXTENSIONS = new Set(["wav", "mp3", "m4a", "aac", "flac"]);
export const MAXIMUM_BYTES = 500 * 1024 * 1024;
export const TRANSCRIPT_MARKER = "<!-- whisperbridge:v1 -->";

export const MODEL = {
  filename: "ggml-base.bin",
  displayName: "Whisper Base Multilingual",
  sizeBytes: 147_951_465,
  sha256: "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe",
  url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"
} as const;
