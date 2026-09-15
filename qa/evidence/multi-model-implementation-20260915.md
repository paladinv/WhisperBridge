# Multi-model implementation evidence — 2026-09-15

Environment: Apple M4 Max MacBook Pro, macOS 26.4.1, Xcode 26.4.1, arm64, LM Studio local plugin installer, `@lmstudio/sdk` 1.4.0, `mlx-audio-swift` 0.1.3.

WhisperBridge now has a per-chat speech-model selector, 23 official Whisper variants, Moonshine, Parakeet, Cohere, and Granite. Model descriptors contain immutable repository revisions, exact runtime files, sizes, SHA-256 values, license and attribution, supported languages, output capability, memory guidance, and availability. MOSS and Canary-Qwen remain hidden behind explicit native-compatibility gates.

The final plugin build and 23-test run passed. The text-only 10,000-call gate took 10.15 ms and made no model/helper call. The final native test milestone reused one successful build receipt and passed all 11 expected selectors with zero failed, missing, unexpected, or unrun selectors. Extracted Xcode JSON is under `.build-artifacts/results/multi-engine-*.json`.

After the final source audit, `project.yml` was corrected to own the exact MLX package declaration and the checked-in project was regenerated. A fresh post-generation receipt passed with zero Xcode-reported errors or warnings, and its 11-selector `test-without-building` milestone passed in full. These post-generation files are the authoritative final native evidence.

The packaged helper passed real-speech checks through both Whisper and MLX code paths. The headless LM Studio SDK integration uploaded the 103,362-byte fixture through `FileHandle`, resolved its host-managed path, produced the expected transcript, consumed the audio attachment, preserved the preprocessor flow, and ended with `Audio transcribed locally`. Evidence is in `.build-artifacts/logs/multi-engine-lmstudio-integration.stdout.log` and the packaged-helper JSONL logs.

The persistent plugin installed successfully as `paladinv/whisperbridge`. The deployed helper hash is `798f007480a1f0804771a5c8557a9401ee1c6a2201ad295b2e315bc4ad34e079`, matching the repository package. The installed production JavaScript includes the Speech model field and larger Whisper/MLX catalog.

Manual product states remain unchanged unless their complete pass conditions were exercised. The actual LM Studio composer selector, per-chat restart persistence, concurrent chats, preprocessor ordering, every-checkpoint download/inference, licensed multilingual corpus, MOSS diarization, peak RSS, and novice no-terminal installation are still NOT_RUN or gated. Automated passes must not be used to report those product cases as passing.
