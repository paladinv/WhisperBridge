# Implementation regression report

Date: 2026-09-14. Host: Apple M4 Max MacBook Pro, macOS 26.4.1. Toolchain: Xcode 26.4.1 (17E202). Configuration: arm64 Debug with code signing disabled for the application build.

## Scope and affected groups

| Changed area | Focused verification |
| --- | --- |
| Domain state, file limits, transcript editing, cancellation, and model manifest/store | `DomainTests` — 6 selectors |
| AVFoundation inspection and 16 kHz mono PCM conversion | `AudioDecoderTests` — 2 selectors |
| Pinned `whisper.cpp` bridge and real model inference | `WhisperSmokeTests` — 1 selector |
| Model hashing and end-to-end short-file latency | `PerformanceTests` — 2 selectors, run serially |
| SwiftUI layout, resources, entitlements, and app entry point | Build plus macOS application launch smoke check |

The repository has no reader component, `ui-reader-smoke` group, iOS target, simulator target, or test catalog. Those unrelated selectors were excluded rather than reported as coverage.

## Build and execution

The source/configuration fingerprint changed when `PerformanceTests.swift` and the generated Xcode project were updated, so one fresh `build-for-testing` was required. It completed in 5.354 seconds with 0 build errors and 0 build warnings. Every test run then used `test-without-building` with the same successful receipt and `.build-artifacts/test-cache/DerivedData` cache.

Because code signing is disabled for the local application build, the generated unhosted XCTest bundle received an ad hoc signature after compilation. This allows Xcode's test runner to load the bundle without changing the application signing setting. Each Xcode action used repository-local Derived Data, package, cache, log, and result paths.

| Run | Selected selectors | Command duration | Result |
| --- | ---: | ---: | --- |
| Focused domain and audio unit groups | 8 | 1.982 s | 8 passed |
| Real Whisper functional smoke | 1 | 1.388 s | 1 passed; selector duration 0.208 s |
| Performance group, serial | 2 | 1.485 s | 2 passed |
| Final complete milestone | 11 | 1.604 s | 11 passed |
| Application launch smoke | UI process | More than 6 s before intentional termination | Launched without an emitted runtime error |

The model hash selector completed in 0.072 seconds against a 3-second budget. End-to-end decode and transcription of the 3.1-second local speech fixture completed in 0.205 seconds against a 15-second budget. These are regression budgets and measurements for this host, not claims for every supported Mac. This is the first implemented version, so no earlier application benchmark exists for a before/after comparison.

## Exact final accounting

- Expected selectors: 11 unique
- Observed selectors: 11 unique
- Passed: 11
- Failed: 0
- Missing: 0
- Unexpected: 0
- Unrun: 0
- Duplicate selectors in the final milestone: 0
- Retried failed selectors in this regression run: 0

The machine-readable accounting and extracted XCTest JSON are retained under `.build-artifacts/regression-20260914/`. Manual product QA remains 0 passed; this report does not replace the signed-package, privacy, accessibility, LM Studio interoperability, corpus accuracy, resource, or novice-user cases in the QA ledger.

After the final milestone passed, redundant build and failed/duplicate run artifacts were removed in one scoped cleanup. The retained reusable Derived Data cache is 125,932 KiB (about 123 MiB), below the 10 GiB ceiling. The complete remaining `.build-artifacts` directory is 273,240 KiB (about 267 MiB), including the pinned model and speech fixture needed to repeat the performance checks.

## LM Studio plugin implementation addendum

The 2026-09-14 plugin change added a TypeScript prompt preprocessor, model manager, native-helper protocol, Apple silicon command-line target, packaged runtime, and plugin-focused tests. A rebuild was required because `project.yml`, the generated Xcode project, and Swift sources changed. All build output, caches, logs, result bundles, model data, and fixtures remained below `.build-artifacts/`.

| Verification group | Selected selectors | Duration or measurement | Result |
| --- | ---: | ---: | --- |
| TypeScript static build | compilation | less than 1 s | passed |
| Plugin unit and contract tests | 16 | 0.179 s | 16 passed |
| Packaged helper real-speech smoke | 1 | 8.00 s cold; 0.61 s warm | passed with expected transcript |
| Installed helper real-speech smoke | 1 | 14.3 s command wall time | passed with expected transcript and bounded progress |
| LM Studio file-handle integration | 1 | 1.27 s warm command time | passed upload, managed path, transcript replacement, attachment consumption, and final status |
| Existing Swift domain/decoder/Whisper/performance regression | 11 | 0.437 s direct XCTest execution | 11 passed |
| Package content inspection | one package | 5.7 MB unpacked | passed; no duplicate framework and an explicit framework load path |

The plugin test selectors cover the text-only bypass, idempotence, attachment mutation safety, context-overflow safety, multiple-audio rejection, prompt formatting, filename sanitization, model data-directory isolation, versioned helper communication, and helper cancellation. The latest 10,000-call text-only microbenchmark took 6.98 ms on this host. This establishes negligible local preprocessor overhead in the mocked no-attachment path; an installed LM Studio prompt-latency comparison remains part of blocked native QA.

No Xcode rebuild was needed for the installation and headless-integration follow-up because no Swift, project, configuration, or toolchain input changed; the previously verified helper binary was reused. The new TypeScript integration runner initially failed static compilation because CommonJS disallows top-level `await`. After wrapping it in an async entry function, the focused `npm run build` retry passed in 0.319 seconds. The 16 unit selectors passed in 0.179 seconds, and the new LM Studio file-handle selector passed on its first execution in 1.27 seconds. The compile retry is build history rather than selector coverage; no additional selector retry was counted.

The first `xcodebuild test-without-building` attempt was sandbox-blocked from Apple's test service. The escalated retry reached the test service but it reported that it could not create the on-disk, valid XCTest bundle. This infrastructure retry is retained in the Xcode logs and result bundles. Direct `xcrun xctest` execution of that same built bundle then passed all 11 expected selectors. No source rebuild occurred between the escalated Xcode attempt and direct bundle execution.

Exact automated accounting for the plugin milestone:

- Expected unique selectors: 30
- Passed: 30
- Failed: 0
- Missing: 0
- Unexpected: 0
- Unrun: 0
- Retried selectors: 11 through the direct XCTest runner after Xcode test-runner infrastructure failure; counted once in coverage

The official installer succeeded from an LM Studio-readable staging directory. The installed process connected and registered its prompt preprocessor, its deployed helper passed the real-speech fixture using the verified model cache, and the headless SDK test passed the supported file-handle contract without System Events access. At that checkpoint QA-054 remained BLOCKED because the actual composer attachment flow and no-terminal installation step had not been executed. Other native product cases remained NOT_RUN. These product states did not change the automated accounting above. Failed/interrupted result bundles were retained because the installed native milestone had not passed. The complete `.build-artifacts/` directory was 778,544 KiB (about 760 MiB). Its reusable test Derived Data was 125,924 KiB, and the two retained run-specific Derived Data directories were 125,972 KiB and 125,976 KiB (about 123 MiB each), all below 10 GiB.

## Auto-language correction addendum

The first real composer attachment reached WhisperBridge but exposed a `whisper.cpp` parameter error: Auto mode enabled detection-only behavior, so Whisper identified Chinese and returned before decoding transcript segments. `WhisperEngine` now passes the `auto` language value with detection-only mode disabled. The fixed installed helper transcribes that same private recording successfully; private transcript content remains in ignored evidence only. QA-054 is FAIL until the corrected hook succeeds on a composer retry. See `qa/evidence/auto-language-fix-20260914.md` for command durations, build reuse, focused selectors, final accounting, and the separate RAG ordering observation.

## Multi-model implementation addendum

Date: 2026-09-15. The change adds the per-chat selector, 23 official Whisper choices, four enabled MLX-engine profiles, atomic multi-file storage, protocol v2 adapters, pinned Swift dependencies, language gating, cache confinement, model smoke tooling, and ten new manual QA cases. MOSS and Canary-Qwen are implemented behind unavailable catalog gates; the reviewed MOSS 5-bit checkpoint fails MLX Audio Swift 0.1.3's VQ-adaptor layout check, and Canary-Qwen has no verified native Swift checkpoint.

The TypeScript group selected 23 unique unit/contract/performance selectors. All 23 passed in 0.943 seconds on the final run. Its 10,000-call text-only preprocessor measurement was 10.15 ms, below the 15 ms gate, and launched no helper. This preserves the pre-configuration early return and found no measurable ordinary text-path regression within the established budget.

The source/project fingerprint changed, so the macOS suite required one `build-for-testing`; the sandbox-blocked attempt produced no receipt, and the permitted retry succeeded. The Xcode receipt reports 6.941 seconds, zero errors, and zero warnings; total command wall time including SwiftPM/test-service startup was about 31.5 seconds. All later native runs reused `.build-artifacts/test-cache/DerivedData` with that receipt.

| Run | Selected selectors | Command wall time | Result |
| --- | ---: | ---: | --- |
| Domain and audio focused groups | 8 | about 8.8 s on permitted retry | 8 passed |
| Real Whisper Base smoke | 1 | about 8.9 s | passed; selector 0.25 s |
| Performance group, serial | 2 | about 7.0 s | passed; selectors 0.068 s and 0.20 s |
| Final complete native milestone | 11 | about 8.5 s | 11 passed |
| LM Studio file-handle integration | 1 | 0.79 s | passed with exact transcript, attachment consumption, and final status |

Final native accounting is 11 expected unique selectors, 11 passed, 0 failed, 0 missing, 0 unexpected, and 0 unrun. Focused runs repeat those selectors as pre-milestone evidence and do not add coverage. No failed selector was retried. The first focused command was blocked before execution by sandboxed Apple test services; its permitted retry is infrastructure history.

Real packaged-helper checks passed for protocol v1 Whisper Base and protocol v2 Moonshine with the exact sentence “Whisper Bridge turns audio into text for local models.” The Moonshine silence check returned the expected no-speech message. Its first evidence assertion expected the internal spelling `no_speech`; the helper correctly returned the existing `noSpeech` code, and the corrected assertion passed. This is evidence-script retry history rather than duplicate coverage.

Local checkpoint smoke evidence also records English WER 0 for Moonshine, Parakeet, Cohere, and Granite on the short fixture. On the synthetic 31-second repeated-sentence performance fixture, Moonshine ran in 2.47 s at WER 0, Parakeet in 0.71 s at WER 0, Cohere in 1.21 s at WER 3.75%, and Granite in 1.10 s faster than real time. Granite collapsed the repeated phrase, so that run is performance evidence only. These engineering fixtures do not satisfy the pending licensed multilingual, speaker-diarization, every-checkpoint, peak-RSS, or actual-composer QA gates.

The official LM Studio installer updated `paladinv/whisperbridge` from LM Studio's readable working directory without System Events. The installed helper SHA-256 matches the packaged helper, its MLX Metal resource is present, and the generated production bundle contains the new selector/catalog. Manual selector visibility, per-chat persistence, actual composer use for every engine, RAG ordering, accessibility, update, and novice installation remain NOT_RUN in the 73-case QA ledger.

Before cleanup, reusable Derived Data was 312,056 KiB and the release-helper Derived Data was 2,139,272 KiB, both below 10 GiB. Large downloaded checkpoint fixtures and failed/intermediate result artifacts are removed only after the final verification step; retained final evidence remains repository-local.

The final audit then added the missing `mlx-audio-swift` declaration to `project.yml` and regenerated the checked-in Xcode project. Because that changed the recorded project fingerprint, a new `build-for-testing` receipt was required. It succeeded in about 6.8 seconds of command wall time; the extracted action duration was 1.63 seconds with zero errors and warnings. The post-generation `test-without-building` milestone reused that receipt and passed the same 11 expected selectors: 11 passed, 0 failed, 0 missing, 0 unexpected, and 0 unrun. This supersedes the prior final native milestone as the completion result.
