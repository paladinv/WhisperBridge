# Product specification — proposed v1

## Outcome and audience

A casual LM Studio user can attach a saved voice memo, interview, or lecture to a normal LM Studio prompt and have Whisper convert it to local text before the chosen model responds. The plugin requires no developer tools or separately launched app. The user chooses the audio and selects Send; the resulting transcript is visible in LM Studio history.

Target the user's current macOS context first: Apple Silicon, macOS 14 or newer, with exact supported OS releases validated before publication. Intel Mac, Windows and Linux are future ports, not implied support. No specific LM Studio version is certified yet. Test the current stable release at release time and the previous supported release; record exact build numbers.

## Scope and decisions

| Requirement | Acceptance contract |
| --- | --- |
| R01 Easy setup | One LM Studio plugin installation; guided model download; no shell, Python, Homebrew, FFmpeg installation, API key, or separately launched app required. |
| R02 File import | One file per job. WAV PCM, MP3, unprotected M4A/AAC and FLAC are target formats, conditional on decoder QA. Validate content, not just extension. |
| R03 Local model | One recommended multilingual Whisper base model initially; display actual download bytes and storage needs from a pinned manifest. Verify SHA-256 before loading; provide Retry and Cancel. |
| R04 Recognition | Auto language by default; manual language override. Preserve source language. No translation, speaker identification or automatic rewriting in v1. |
| R05 Transcript visibility | Unicode transcript is inserted into the sent user message and retained in LM Studio history. Review-before-send is conditional on a supported composer API and is not promised for the preprocessor version. |
| R06 Prompt handoff | The prompt preprocessor runs only after the user selects Send, preserves the typed instruction, consumes the audio attachment, and supplies the delimited transcript to the chosen model. |
| R07 Recovery | Cancel, retry, clear error messages, and an intact typed instruction and chat after a failed job. |
| R08 Privacy | Audio and recognition stay local after model download. No telemetry by default. No transcript/audio in diagnostic logs. Explain LM Studio history retention. |
| R09 Accessibility | Keyboard-only flow, VoiceOver names/state announcements, visible focus, text scaling and sufficient contrast; status does not rely on color alone. |
| R10 Resource limits | Proposed maximum: 500 MiB and 2 hours, both inclusive. Reject over-limit jobs before inference; enforce decoded duration too. One active job, bounded decode buffers. |
| R11 Lifecycle | Offline repeat use; atomic updates; cleanup of intermediate audio; no changes to original files; safe LM Studio restart and plugin removal. |
| R12 Native integration | Supported LM Studio prompt-preprocessor hook, preserved message content and chat isolation, validated installation. No unsupported UI injection claim. |

The current native transcription core enforces the 500 MiB and two-hour input limits. The plugin must preserve those limits. Timing, decoder compatibility, and usability thresholds remain release targets until the manual QA matrix is complete. If FLAC fails the supported-platform decoder matrix, bundle and license a decoder or remove FLAC from advertised support before release. Never ask casual users to resolve codecs.

## Interaction contract

Use LM Studio's existing chat composer and attachment control. When the user selects Send, the plugin moves through Model download → Validating → Transcribing → Prompt transformation using in-app status. Cancellation or an error must prevent a partial prompt from reaching the model. Multiple audio files receive a clear action instead of silent selection.

During a job show the active stage and elapsed time, with Cancel. Show percentages only if based on real progress; do not freeze at fabricated 99%. Retry uses the selected language and file, starts a fresh job, and cannot merge stale callbacks into another transcript or chat.

“No speech detected” is a normal result, not an error or an invented transcript. Low-quality recordings receive a plain notice to review names and numbers; do not invent word-level confidence scores. Overlapping speakers may be inaccurate and are not diarized. Manual language selection is the recovery path for a wrong auto-detection.

## Installation and architecture

The target implementation consists of an LM Studio TypeScript prompt preprocessor and a packaged local Whisper runtime. The preferred runtime spike reuses the existing AVFoundation decoder and pinned `whisper.cpp` engine through a headless helper; a WASM runtime is the fallback if supported plugin distribution cannot launch or package that helper. Transcription does not require LM Studio's HTTP server. Runtime work must not block the LM Studio UI. See [the gated implementation plan](LM_STUDIO_PLUGIN_PLAN.md).

First use explains the model download size, destination, and why internet is needed. Download to a partial file, check expected size/hash, then rename atomically. Insufficient storage and interrupted downloads retain a recoverable state. Do not execute unverified binaries from a model download. Package native libraries with the plugin, pin their versions, and include their notices. Store installed data only in locations LM Studio grants to the plugin; all development/test paths in this repository must remain within the workspace per AGENTS.md.

## Data contract

Keep a job ID, chat/job scope, source display name, decoded duration, selected/detected language, model version/hash, and raw transcript in memory during preprocessing. Retain no audio copy beyond the active job. Intermediate decode files are removed on completion/cancel and after restart following a crash. The transformed user message is retained by LM Studio according to its chat-history behavior. Original recordings are never edited or deleted.

Plugin removal does not erase messages already stored in LM Studio history. Model removal and cache retention must be explicit choices. Diagnostics contain versions, stage codes, and timings, with private paths and content redacted.

## LM Studio prompt behavior

The plugin preserves the user's typed instruction and appends a clearly labeled, delimited transcript. It does not automatically ask the model to rewrite the source. Delimiters help separate instruction from source text but do not guarantee protection from prompt injection.

Test the real LM Studio context-overflow response and never silently summarize or truncate a transcript. If the plugin API exposes the selected model's exact context state, use it; otherwise give a clear size error before inference. The transformed transcript should remain recoverable when a selected model cannot accept it.

## Definition of done

The packaged plugin passes the baseline QA suite and novice study on supported machines; privacy, performance, and recovery evidence exists; install/uninstall work without terminal instructions; dependencies and licenses are recorded. In-app claims require the plugin acceptance suite. Compiling or checking the QA files alone never satisfies the release definition.
