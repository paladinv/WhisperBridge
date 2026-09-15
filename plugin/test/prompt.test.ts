import assert from "node:assert/strict";
import test from "node:test";
import { MAXIMUM_BYTES, TRANSCRIPT_MARKER } from "../src/constants";
import { formatPrompt, isSupportedAudio, safeDisplayName, validateAudio } from "../src/prompt";

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
  const result = formatPrompt("Summarize this", " Hello world. ", "meeting.m4a", true);
  assert.ok(result.startsWith(TRANSCRIPT_MARKER));
  assert.match(result, /User request:\nSummarize this/);
  assert.match(result, /Audio transcript from “meeting\.m4a”/);
  assert.match(result, /BEGIN WHISPERBRIDGE TRANSCRIPT/);
  assert.match(result, /Hello world\./);
});

test("supports an audio-only prompt and optional filename", () => {
  const result = formatPrompt("   ", "Spoken note", "private.m4a", false);
  assert.doesNotMatch(result, /User request/);
  assert.doesNotMatch(result, /private\.m4a/);
});

test("rejects an empty transcript", () => {
  assert.throws(() => formatPrompt("Summarize", "  ", "meeting.wav", true), /No speech/);
});

test("sanitizes control characters in displayed filenames", () => {
  assert.equal(safeDisplayName("meeting\n\u0000name.wav"), "meeting name.wav");
});
