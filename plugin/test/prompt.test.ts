import assert from "node:assert/strict";
import test from "node:test";
import { MAXIMUM_BYTES, TRANSCRIPT_MARKER } from "../src/constants";
import { formatPrompt, formatStructuredTranscript, isSupportedAudio, safeDisplayName, validateAudio } from "../src/prompt";
import { parseSettingsMarker } from "../src/settings";

const settings = {
  modelID: "whisper-base-multilingual",
  language: "auto",
  includeFilename: true,
  diarization: false,
  timestampGranularity: "segment" as const,
  compact: false,
  removeFillers: false,
  saveToLibrary: false,
  preset: "balanced" as const,
  strategy: "greedy" as const,
  beamSize: 5,
  greedyBestOf: 5,
  patience: 1,
  temperature: 0,
  temperatureIncrement: 0.2,
  noSpeechThreshold: 0.6,
  logProbabilityThreshold: -1,
  scope: "inherit" as const
};

test("detects supported audio extensions without case sensitivity", () => {
  assert.equal(isSupportedAudio({ name: "meeting.M4A", sizeBytes: 20 }), true);
  assert.equal(isSupportedAudio({ name: "notes.pdf", sizeBytes: 20 }), false);
});

test("rejects empty and oversized audio before runtime work", () => {
  assert.throws(() => validateAudio({ name: "empty.wav", sizeBytes: 0 }), /empty/);
  assert.throws(
    () => validateAudio({ name: "large.wav", sizeBytes: MAXIMUM_BYTES + 1 }),
    /500 MiB/
  );
});

test("preserves the instruction and delimits the transcript", () => {
  const result = formatPrompt("Summarize this", " Hello world. ", "meeting.m4a", settings);
  assert.ok(result.startsWith(TRANSCRIPT_MARKER));
  assert.match(result, /User request:\nSummarize this/);
  assert.match(result, /Audio transcript from “meeting\.m4a”/);
  assert.match(result, /BEGIN WHISPERBRIDGE TRANSCRIPT/);
  assert.match(result, /Hello world\./);
  assert.deepEqual(parseSettingsMarker(result), settings);
});

test("supports an audio-only prompt and optional filename", () => {
  const result = formatPrompt("   ", "Spoken note", "private.m4a", { ...settings, includeFilename: false });
  assert.doesNotMatch(result, /User request/);
  assert.doesNotMatch(result, /private\.m4a/);
});

test("rejects an empty transcript", () => {
  assert.throws(() => formatPrompt("Summarize", "  ", "meeting.wav", settings), /No speech/);
});

test("sanitizes control characters in displayed filenames", () => {
  assert.equal(safeDisplayName("meeting\n\u0000name.wav"), "meeting name.wav");
});

test("renders speaker segments, timestamps, compact mode, and filler presentation", () => {
  const result = { text: "Um, hello there", segments: [{ start: 1.25, end: 2, speaker: "Speaker 1", text: "Um, hello there" }] };
  assert.equal(formatStructuredTranscript(result, { ...settings, removeFillers: true }), "[00:00:01.250] Speaker 1: hello there");
  assert.equal(formatStructuredTranscript(result, { ...settings, compact: true }), "Speaker 1: Um, hello there");
});
