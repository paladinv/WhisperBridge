# Alternate selection implementation evidence

Date: 2026-09-15. Host: Apple M4 Max MacBook Pro, macOS 26.4.1. LM Studio: 0.4.24+1. Commit under test: working tree after `89b176d`.

## Implemented behavior

WhisperBridge now accepts a first-line `/wb` command only when one supported audio file is attached. Chat commands are removed from the outgoing instruction and the resolved model, language, filename behavior, and inheritance scope are recorded in an anchored visible settings line. Global commands use an atomic versioned file under WhisperBridge's existing data directory and commit only after transcription and context validation succeed. The native LM Studio schema remains registered with an explicit inheritance option for use after host bug #2365 is fixed.

The friendly aliases and every available catalog model ID are covered by automated tests. MOSS and Canary-Qwen remain unavailable and return their catalog reason. Text-only messages, including text-only `/wb` lines, return before configuration, history, filesystem, model, or helper work.

## Automated verification

| Group | Selected coverage | Duration | Result |
| --- | ---: | ---: | --- |
| Focused prompt/settings tests | 27 selectors | 0.209 s | 27 passed |
| Final TypeScript build | compilation | about 0.6 s | passed |
| Final plugin suite | 38 selectors | 0.948 s | 38 passed |
| Reused native macOS suite | 11 selectors | 12.83 s permitted retry | 11 passed |
| LM Studio file-handle integration | 1 real-audio flow | 5.9 s command wall time | passed |
| QA catalog validation | 78 cases | under 1 s | valid; manual results remain 0 passed |

The final 10,000-call text-only measurement was 8.85 ms against the 15 ms gate. It read no configuration or history, touched no settings/model path, and launched no helper. The real LM Studio file-handle flow uploaded a 103,362-byte fixture, applied `/wb model=everyday language=en filename=off`, removed the directive, emitted the selected-settings line, omitted the filename, consumed the audio attachment, and produced the exact expected transcript.

No Swift source, Xcode project, build configuration, or toolchain input changed. The successful `.build-artifacts/test-cache/DerivedData` receipt was therefore reused without rebuilding. The first sandboxed `test-without-building` attempt stopped during SwiftPM initialization because it tried to write host-global diagnostics; it executed no selectors. The permitted retry passed. `xcresulttool` was run standalone, its JSON was saved under `.build-artifacts/fallback-selection/results/`, and the JSON was processed separately without a pipeline or `jq`.

Native exact accounting: 11 expected unique selectors, 11 observed, 11 passed, 0 failed, 0 missing, 0 unexpected, and 0 unrun. The earlier sandbox failure contained no selector retry and is infrastructure history. Plugin exact accounting: 38 expected unique selectors, 38 passed, 0 failed, 0 missing, 0 unexpected, and 0 unrun.

LM Studio's official installer updated `paladinv/whisperbridge` from its readable staging directory in 0.82 seconds. The installed production bundle contains the fallback parser/settings store and the installed README contains copyable commands plus all larger Whisper IDs. The packaged and installed helper hashes remain identical. LM Studio's log confirms that the installed prompt preprocessor registered after installation.

Manual composer QA for QA-074 through QA-077 remains NOT_RUN. QA-064 and QA-078 require an LM Studio build where bug #2365 is fixed. No manual product case was promoted based on automated evidence.

## Artifacts and cache

- Extracted native results: `.build-artifacts/fallback-selection/results/native-final-retry1.json`
- Exact accounting: `.build-artifacts/fallback-selection/exact-accounting.json`
- Reusable native Derived Data: 313,216 KiB
- Release-helper Derived Data: 2,139,272 KiB
- Source packages: 525,904 KiB

Each reusable cache remains below 10 GiB.
