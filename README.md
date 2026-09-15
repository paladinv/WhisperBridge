# WhisperBridge

**Local audio transcription inside LM Studio prompts.**

![WhisperBridge logo](assets/logo.svg)

WhisperBridge is moving toward an in-app [LM Studio](https://lmstudio.ai/) plugin. The intended workflow is to attach a recording to an LM Studio prompt, transcribe it locally with Whisper when Send is selected, and pass the resulting text to the chosen model. The everyday workflow should need no Python, API key, database, local server, or separately launched app.

The repository currently contains a working native macOS companion and its tested transcription core. The official plugin route is feasible in principle, but audio byte access and local-runtime packaging remain explicit proof gates. See the [LM Studio plugin feasibility and implementation plan](docs/LM_STUDIO_PLUGIN_PLAN.md). WhisperBridge remains an independent project and will use supported plugin hooks rather than patching LM Studio.

## What works

- One-click download and SHA-256 verification of Whisper Base Multilingual
- WAV, MP3, M4A, AAC, and FLAC files up to 500 MiB or two hours
- Automatic language detection or an explicit language choice
- Local decoding and transcription through the pinned `whisper.cpp` framework
- Progress and cancellation for audio preparation and transcription
- Editable transcript with reset, clear, UTF-8 text export, and **Copy for LM Studio**
- macOS App Sandbox, with access limited to files the user chooses

The model download is the only network operation in the core workflow. Audio and transcript text stay on the Mac. Copying text uses the system clipboard, which can sync if Universal Clipboard is enabled.

## Run the app

These instructions run the current companion implementation while plugin integration is developed.

Requirements: macOS 14 or newer, Apple silicon, and Xcode 16 or newer.

1. Clone the repository and open `WhisperBridge.xcodeproj` in Xcode.
2. Select the **WhisperBridge** scheme and **My Mac** destination.
3. Run the app.
4. Choose **Download Model** on first launch, then select or drop an audio file.
5. Select **Transcribe**, review the result, and choose **Copy for LM Studio**.

The recommended model is about 148 MB and is stored in the app's Application Support container. No model is committed to Git.

## Build and test

The repository includes a repeatable script that keeps Derived Data, Swift module caches, result bundles, fixture data, and logs under `.build-artifacts/`:

```sh
./scripts/build-and-test.sh
```

Eleven XCTest checks cover file policy, invalid input, PCM conversion, model integrity, edit state, cancellation, real `whisper.cpp` transcription, and performance budgets when the local smoke model and fixture are present. A fresh clone skips the large-model smoke and performance checks that require those local assets.

The separate QA kit covers novice setup and product behavior that code tests cannot prove:

- [Complete use cases](docs/USE_CASES.md)
- [Hands-on QA strategy and release gates](qa/PLAN.md)
- [Step-by-step QA cases](qa/CASES.md)
- [Machine-readable cases](qa/cases.json) and [execution records](qa/results.json)
- [Implementation regression report](qa/REGRESSION_REPORT.md)
- [LM Studio plugin feasibility and implementation plan](docs/LM_STUDIO_PLUGIN_PLAN.md)

Validate the QA records with:

```sh
python3 scripts/check_qa.py
```

`python3 scripts/check_qa.py --release` remains blocked until the manual baseline cases have been run on a packaged, signed build with licensed fixtures. Automated test success does not mark those product QA cases as passed.

## Project structure

- `Sources/WhisperBridge/` — SwiftUI app, workflow state, audio decoder, model store, and Whisper engine
- `Tests/WhisperBridgeTests/` — automated unit, decoder, and real-engine smoke tests
- `Vendor/whisper.framework/` — pinned universal macOS framework from `whisper.cpp` v1.9.1
- `docs/` — product decisions, reference research, use cases, and roadmap
- `qa/` — manual QA plan, cases, release gates, and evidence records
- `assets/` — editable SVG brand assets

See [third-party notices](THIRD_PARTY_NOTICES.md) for the vendored engine license and provenance. The working name and visual identity are original project concepts and are not official LM Studio or OpenAI branding.
