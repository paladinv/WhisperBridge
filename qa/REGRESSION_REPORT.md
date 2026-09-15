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
