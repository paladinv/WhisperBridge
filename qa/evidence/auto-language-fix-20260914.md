# Auto-language failure and correction — 2026-09-14

Environment: Apple M4 Max MacBook Pro, macOS 26.4.1, Xcode 26.4.1 (17E202), LM Studio 0.4.19+2, `@lmstudio/sdk` 1.4.0, Whisper Base Multilingual SHA-256 `60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe`.

## Actual composer failure

A user enabled `paladinv/whisperbridge`, attached a 45.14-second stereo 48 kHz 24-bit ALAC `.m4a`, and sent the prompt through LM Studio's real composer. The installed preprocessor received the request and returned `No speech was detected. Try another recording or check its volume.` The original message did not reach the model.

The recording was retained only in ignored private test artifacts. Diagnostic output records technical metadata and result length; no private transcript is committed.

## Root cause

The helper set `whisper_full_params.detect_language = true` when the selected language was Auto. In `whisper.cpp`, that flag requests detection-only behavior and returns before segment decoding. The engine correctly identified Mandarin with high confidence, then produced zero transcript segments. Forcing the language to Chinese completed successfully, which isolated the error from audio decoding and volume.

Automatic transcription now supplies Whisper's special `auto` language value while keeping `detect_language` false. This lets Whisper select the language and continue decoding segments.

## Focused regression

The source change affects `WhisperEngine`, the real Whisper smoke selector, both serial performance selectors, and the packaged helper. A Debug `build-for-testing` rebuild was required for the changed source fingerprint and succeeded in 6.706 seconds with zero errors and zero warnings in the xcresult summary. The project-local build receipt and Derived Data were reused for every test execution.

Xcode's focused `test-without-building` action was again unable to communicate with `testmanagerd` because of a sandbox restriction. Its result JSON was extracted and inspected before retrying. No selector ran in that attempt. Direct execution of only the affected Auto-mode smoke selector then passed in 0.283 seconds. The two affected performance selectors passed serially in 0.305 seconds. The final 11-selector milestone passed in 0.433 seconds with zero failures, unexpected tests, or unrun selectors.

The separate Release configuration required one build and completed in 3.933 seconds. TypeScript static compilation passed in 0.536 seconds, and all 16 Node unit/contract selectors passed in 0.181 seconds; the 10,000-call text-only bypass took 7.04 ms. The packaged Release helper transcribed the public fixture in Auto mode in 8.647 seconds. After official reinstallation, its SHA-256 matched the packaged helper and the installed helper transcribed the original private recording in Auto mode in 1.514 seconds on the warm runtime. It detected Chinese and returned 90 transcript characters; content is not included in this evidence.

The refreshed npm archive is `.build-artifacts/releases/lms-plugin-whisperbridge-0.1.0.tgz`, SHA-1 `c29304ff909dd6ea0d2745e064fea3b27aff3a8e`, with 13 files, approximately 2.0 MB compressed and 5.7 MB unpacked. The source, archive, and installed helpers all have SHA-256 `19eb20c50a0d8b26a20371d358096f7efd6ef7a77f7e5270a4420c87beca3ad0`.

Automated accounting remains 30 unique selectors because the Auto-mode public/installed checks replace the corresponding earlier helper checks rather than adding duplicate coverage: 30 passed, 0 failed, 0 missing, 0 unexpected, and 0 unrun. The focused smoke and performance executions are retry history covered again by the final milestone.

All failed and successful result bundles remain available because the corrected composer milestone is awaiting retry. `.build-artifacts/` is 953,836 KiB (about 931 MiB). The reusable Debug Derived Data is 210,360 KiB (about 205 MiB), Release helper Derived Data is 232,964 KiB (about 228 MiB), and the scoped fix evidence is 20,308 KiB (about 20 MiB). Every cache remains below 10 GiB.

## Integration ordering observation

LM Studio's bundled `lmstudio/rag-v1` preprocessor ran before WhisperBridge on the same audio message, attempted document retrieval against the `.m4a`, and completed after approximately 66 seconds. WhisperBridge then received the file. This did not cause the Auto-mode failure, but it adds substantial latency and may inject irrelevant RAG text before transcription. Until LM Studio exposes file-type routing or deterministic preprocessor ordering, disable RAG for chats that use WhisperBridge or place WhisperBridge before RAG if the installed LM Studio build exposes ordering controls.

QA-054 is FAIL pending a successful composer retry with the corrected installed helper. Installation, registration, real attachment delivery, failure safety, root cause, and fixed-helper inference are proven; successful transformed-message delivery through the registered hook still needs observation.
