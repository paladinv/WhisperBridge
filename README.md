# WhisperBridge

**Local audio transcription inside LM Studio prompts.**

![WhisperBridge logo](assets/logo.svg)

WhisperBridge is an in-app [LM Studio](https://lmstudio.ai/) prompt-preprocessor plugin. Attach a recording to a prompt and select Send. WhisperBridge downloads the chosen speech model on first use, transcribes locally, and passes the text to the chosen language model. The everyday workflow needs no Python, API key, database, local server, or separately launched app.

The repository now contains an LM Studio prompt-preprocessor plugin, a packaged Apple silicon transcription helper, and the original native macOS companion. The plugin uses LM Studio's supported attachment path API, transcribes locally, consumes only the successfully processed audio attachment, and inserts the transcript into the outgoing message. See the [implementation and remaining release gates](docs/LM_STUDIO_PLUGIN_PLAN.md). WhisperBridge remains an independent project and does not patch LM Studio.

## What works

### LM Studio plugin

- Constant-time bypass for text-only prompts, without model or helper startup
- WAV, MP3, M4A, AAC, and FLAC attachment detection
- Prompt-based per-chat and application-wide model selection with 23 Whisper sizes/quantizations plus Moonshine, Parakeet, Cohere, and Granite
- First-use, multi-file model download with pinned revisions, exact sizes, SHA-256 verification, atomic activation, and safe concurrent reuse
- LM Studio status updates and cancellation propagation
- Packaged Apple silicon Swift/AVFoundation/`whisper.cpp` helper
- Preservation of typed instructions and unrelated attachments
- Transcript insertion into the sent message and LM Studio history

The plugin SDK is currently in private beta. The official local installer has installed and registered WhisperBridge on LM Studio 0.4.19+2, the deployed native helper passes the real-speech smoke fixture, and a headless integration test passes audio through LM Studio's supported file-handle service. Release validation still requires the attachment workflow in the actual composer and a no-terminal Hub installation.

To use the installed plugin, open a Chat and select the **Integrations** panel in the chat's right sidebar (hammer icon), then enable `paladinv/whisperbridge`. Audio preprocessing is enabled there rather than under **Settings → Integrations → Tool Call Confirmation**. Transcript Studio also registers the bounded, read-only `search_transcripts` and `get_transcript_excerpt` tools; LM Studio may list those individual tools in its confirmation settings.

LM Studio 0.4.23 and 0.4.24 do not render plugin configuration fields because of [LM Studio bug #2365](https://github.com/lmstudio-ai/lmstudio-bug-tracker/issues/2365). Until the host fix ships, put a command on the first line of an audio prompt:

```text
/wb model=better language=auto filename=on
Summarize this recording.
```

The command is removed before the prompt reaches the language model. Its resolved settings are shown with the transcript and inherited by later audio messages in that chat. Use `/wb default model=best` to save an application-wide default, `/wb reset` to return a chat to inherited defaults, or `/wb default reset` to clear the saved global defaults. Commands require one attached audio file; text-only prompts remain untouched. Model selection does not use the network, and the selected model downloads only when that audio prompt is sent.

Whisper Base Multilingual remains the default. The selector also offers every official `whisper.cpp` checkpoint larger than Base: Small and Medium English/multilingual Q5, Q8, and full variants, Large v1, Large v2/v3 Q5, Q8 where published, full variants, and Large v3 Turbo Q5/Q8/full. See the [model catalog](docs/MODELS.md) for languages, storage, licenses, pinned revisions, and the two gated adapters.

For current LM Studio beta builds, disable the bundled RAG integration in audio-transcription chats. RAG treats audio as a document and may run before WhisperBridge, adding substantial delay and irrelevant context. If the app exposes integration ordering, place WhisperBridge before RAG.

### Transcript Studio

- One-click download and SHA-256 verification of Whisper Base Multilingual
- WAV, MP3, M4A, AAC, and FLAC files up to 500 MiB or two hours
- Automatic language detection or an explicit language choice
- Local decoding and transcription through the pinned `whisper.cpp` framework
- Progress and cancellation for audio preparation and transcription
- SQLite/WAL transcript library with FTS5 full-text and speaker search
- Structured segment and word timing, compact display, conservative reversible filler hiding, and segment editing/deletion
- Manual speaker creation, assignment, split/merge correction, plus optional local FluidAudio diarization on macOS 15+
- Full-recording or selected-range transcription; range replacement leaves every segment outside the selection unchanged
- Fast, Balanced, and Accurate decoder presets with validated Whisper advanced controls
- TXT, Markdown, JSON, CSV, SRT, VTT, and compatible `.tst` project import/export
- Audio playback, range selection, searchable snippets, and **Copy for LM Studio**
- macOS App Sandbox, with access limited to files the user chooses

The model download is the only network operation in the core workflow. Audio and transcript text stay on the Mac. Copying text uses the system clipboard, which can sync if Universal Clipboard is enabled.

## Run the app

These instructions run the companion fallback while plugin release validation is completed.

For plugin development and local installation, see [Plugin development](docs/PLUGIN_DEVELOPMENT.md).

Requirements: macOS 14 or newer, Apple silicon, and Xcode 16 or newer.

1. Clone the repository and open `WhisperBridge.xcodeproj` in Xcode.
2. Select the **WhisperBridge** scheme and **My Mac** destination.
3. Run the app.
4. Choose **Download Model** on first launch, then import an audio file.
5. Select **Transcribe All** or choose a range and select **Transcribe Selection**.
6. Edit segments and speakers, search the local library, export, or choose **Copy for LM Studio**.

The expanded prompt syntax includes:

```text
/wb diarize=on timestamps=word compact=on fillers=off library=on preset=accurate
Summarize this meeting.
```

```text
/wb start=01:30 end=03:45 strategy=beam beam-size=5
Analyze this section.
```

`start` and `end` must be supplied together. WhisperBridge inspects the recording and rejects an out-of-range selection before any model download or library write. Advanced decoding values are accepted only for `whisper.cpp` models. Library saving remains off unless `library=on` is selected.

The recommended model is about 148 MB. Plugin models are stored under `~/Library/Application Support/LM Studio/WhisperBridge/models/<model-id>/<revision>/`; no model is committed to Git. To reclaim space, quit active transcription and delete only the model-ID directory you no longer want. It will download and verify again if selected later.

## Build and test

The repository includes a repeatable script that keeps Derived Data, Swift module caches, result bundles, fixture data, and logs under `.build-artifacts/`:

```sh
./scripts/build-and-test.sh
```

Twenty XCTest/Swift Testing checks cover file policy, invalid input, PCM conversion, model integrity, edit state, cancellation, SQLite/FTS, archive validation, export formats, real `whisper.cpp` transcription, and performance budgets when the local smoke model and fixture are present. A fresh clone skips the large-model smoke and performance checks that require those local assets.

The separate QA kit covers novice setup and product behavior that code tests cannot prove:

- [Complete use cases](docs/USE_CASES.md)
- [Hands-on QA strategy and release gates](qa/PLAN.md)
- [Step-by-step QA cases](qa/CASES.md)
- [Machine-readable cases](qa/cases.json) and [execution records](qa/results.json)
- [Implementation regression report](QA/REGRESSION_REPORT.md)
- [LM Studio plugin feasibility and implementation plan](docs/LM_STUDIO_PLUGIN_PLAN.md)

Validate the QA records with:

```sh
python3 scripts/check_qa.py
```

`python3 scripts/check_qa.py --release` remains blocked until the manual baseline cases have been run on a packaged, signed build with licensed fixtures. Automated test success does not mark those product QA cases as passed.

## Project structure

- `Sources/WhisperBridgeCore/` — structured transcript model, SQLite/FTS5 library, reversible editing, subtitle/custom export, secure `.tst`, and diarization adapter
- `Sources/WhisperBridge/` — SwiftUI Transcript Studio, workflow state, audio playback/decoder, model store, and Whisper engine
- `Sources/WhisperBridgeCLI/` — headless JSON transcription helper used by the plugin
- `plugin/` — LM Studio TypeScript prompt preprocessor, tests, and packaged native runtime
- `Tests/WhisperBridgeTests/` — automated unit, decoder, and real-engine smoke tests
- `Vendor/whisper.framework/` — pinned universal macOS framework from `whisper.cpp` v1.9.1
- `docs/` — product decisions, reference research, use cases, and roadmap
- `qa/` — manual QA plan, cases, release gates, and evidence records
- `assets/` — editable SVG brand assets

See [third-party notices](THIRD_PARTY_NOTICES.md) for the vendored engine license and provenance. The working name and visual identity are original project concepts and are not official LM Studio or OpenAI branding.
