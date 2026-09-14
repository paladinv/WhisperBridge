# Product specification — proposed v1

## Outcome and audience

A casual LM Studio user can turn a saved voice memo, interview or lecture into editable text without installing developer tools. The user decides what enters the prompt and when it is sent. Whisper performs speech recognition locally; the LM Studio language model answers questions about the resulting text.

Target the user's current macOS context first: Apple Silicon, macOS 14 or newer, with exact supported OS releases validated before publication. Intel Mac, Windows and Linux are future ports, not implied support. No specific LM Studio version is certified yet. Test the current stable release at release time and the previous supported release; record exact build numbers.

## Scope and decisions

| Requirement | Acceptance contract |
| --- | --- |
| R01 Easy setup | One signed/notarized application; guided model download; no shell, Python, Homebrew, FFmpeg installation or API key required. |
| R02 File import | One file per job. WAV PCM, MP3, unprotected M4A/AAC and FLAC are target formats, conditional on decoder QA. Validate content, not just extension. |
| R03 Local model | One recommended multilingual Whisper base model initially; display actual download bytes and storage needs from a pinned manifest. Verify SHA-256 before loading; provide Retry and Cancel. |
| R04 Recognition | Auto language by default; manual language override. Preserve source language. No translation, speaker identification or automatic rewriting in v1. |
| R05 Review | Editable Unicode transcript, original recognition result retained in memory, Reset with confirmation, explicit Copy and Save text. |
| R06 Prompt handoff | Copy only on action; user pastes into LM Studio at their selected location. Never auto-send, steal focus or overwrite another app's draft. |
| R07 Recovery | Cancel, retry, clear error messages and intact prior reviewed output after a failed replacement job. |
| R08 Privacy | Audio and recognition stay local after model download. No telemetry by default. No transcript/audio in diagnostic logs. Explain clipboard and LM Studio history separately. |
| R09 Accessibility | Keyboard-only flow, VoiceOver names/state announcements, visible focus, text scaling and sufficient contrast; status does not rely on color alone. |
| R10 Resource limits | Proposed maximum: 500 MiB and 2 hours, both inclusive. Reject over-limit jobs before inference; enforce decoded duration too. One active job, bounded decode buffers. |
| R11 Lifecycle | Offline repeat use; atomic updates; cleanup of intermediate audio; no changes to original files; explicit unsaved-work handling on quit. |
| R12 Native integration | Conditional follow-on: supported LM Studio hook, preserved message content and chat isolation, validated installation. No unsupported UI injection claim. |

All limits and timing thresholds are proposed acceptance targets, not existing capabilities. If FLAC requires another decoder, bundle and license it or remove FLAC from advertised support before release. Never ask casual users to resolve codecs.

## Screen and interaction contract

One window, with a compact brand mark, “Choose audio” drop zone, selected filename/duration, a language menu under Options, and one main action. States: Welcome → Model download → Ready → Validating → Transcribing → Review. Error and Cancel return to Ready or the prior Review. Save and Copy are disabled until nonempty text exists. Transcribe is disabled during a job. Dropping multiple files explains “Choose one audio file” without silently selecting one.

During a job show the active stage and elapsed time, with Cancel. Show percentages only if based on real progress; do not freeze at fabricated 99%. At completion, focus the review heading without interrupting ongoing editing. If the user selects a new file while a reviewed draft is dirty, ask Keep editing or Discard and continue. Never lose a draft implicitly. Retry uses the selected language and file, starts a fresh job, and cannot merge stale callbacks into another transcript.

“No speech detected” is a normal result, not an error or an invented transcript. Low-quality recordings receive a plain notice to review names and numbers; do not invent word-level confidence scores. Overlapping speakers may be inaccurate and are not diarized. Manual language selection is the recovery path for a wrong auto-detection.

## Installation and architecture

Proposed implementation consists of a native SwiftUI shell, platform audio decoder, pinned local Whisper runtime, and app-managed model manifest/downloader. Transcription needs neither an LLM loaded nor LM Studio's HTTP server. The UI and model work are separated so a long job does not block controls. Decode into bounded chunks with validated offsets; test chunk joins for missing/repeated words. Use CPU fallback if accelerated inference fails, with a clear retry action.

First launch explains the model download size, destination and why internet is needed. Download to a partial file, check expected size/hash, then rename atomically. Insufficient storage and interrupted downloads retain a recoverable state. Do not execute unverified binaries from a model download. Distribute native libraries with the application, pin their versions, and include their notices. Normal installed app data will use its approved application container; all development/test paths in this repository must remain within the workspace per AGENTS.md.

## Data contract

Keep a job ID, source display name, decoded duration, selected/detected language, model version/hash, raw text and edited text in memory. Retain no audio copy beyond the active job. Intermediate decode files are removed on completion/cancel and after restart following a crash. Do not recover private transcripts to disk by default. On quit with unsaved text, offer Save, Discard, Cancel. Original recordings are never edited or deleted.

Save exports UTF-8 plain text to the user's chosen destination; confirm overwrites and preserve edit contents exactly. Clipboard ownership is shared with the OS and may sync; never claim the app can erase all clipboard history. Clearing the app does not clear LM Studio's chat history or an exported file. Diagnostics contain versions, stage codes and timings, with private paths and content redacted.

## LM Studio prompt behavior

Default Copy transfers exactly the reviewed transcript. Users can prepend “Summarize these notes” or their own instruction after pasting. Do not wrap the transcript in a command to rewrite it automatically. A future template mode must clearly label source text and separate it from the user's instruction; delimiters are not a guarantee against prompt injection.

The companion cannot know a chat's remaining token budget. Show character count and advice to shorten/split large text; do not label a guessed token count as exact or silently summarize/truncate. Test the real LM Studio context-overflow response. The user should retain their transcript even when a selected LLM cannot accept it.

## Definition of done

The packaged workflow passes the baseline QA suite and novice study on supported machines; privacy and recovery evidence exists; install/uninstall work without terminal instructions; dependencies and licenses are recorded. Native add-on claims additionally require the native QA suite. Compiling or checking the QA files alone never satisfies either release definition.
