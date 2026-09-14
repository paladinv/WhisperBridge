# Human QA and release plan

## Status and execution

This is an acceptance suite for a future app. No installer, speech runtime, model or recorded-speech fixtures exist in this initial repository. All 63 product cases start NOT_RUN. A blocked environment is not a passing test. Generated silence/noise fixtures can test rejection, but cannot establish recognition accuracy. Do not substitute mock transcript output for speech recognition evidence.

Use `cases.json` as the test definition and `results.json` as the execution ledger. Each result needs status (NOT_RUN, BLOCKED, PASS, FAIL), actual observation, tester, environment and evidence paths. Record app commit/build, OS build, hardware/RAM, LM Studio version/model/context size, Whisper version/hash, language setting, fixture SHA-256 and network state in the environment record. Evidence files must live within the workspace. Keep private recordings and sensitive evidence in the ignored private directories; commit sanitized summaries suitable for future reviewers.

Run cases on the real packaged application, not only its development launch. Give every repeated matrix run a separate ledger copied into `.build-artifacts/qa-runs/<run-name>/results.json`; do not overwrite earlier evidence. The checker accepts `--results` for these ledgers. All advertised platform/version combinations require their own release gate. Use fresh app storage under the workspace for testing. Fixtures stay read-only; hash original files before and after destructive/recovery scenarios.

## Environment matrix

| Dimension | Required coverage |
| --- | --- |
| macOS | Proposed minimum macOS 14 and current supported release at shipping; exact builds recorded. |
| Hardware | Lowest supported Apple Silicon Mac with 8 GiB RAM and a newer 16+ GiB Mac. |
| LM Studio | Current stable at release and previous supported version; local text model loaded for end-to-end checks; also stopped/absent/server-off states. |
| Input | All advertised formats, mono/stereo, 16/44.1/48 kHz, clear/noisy/non-speech, English/French/Japanese, short/long/boundary. |
| Network | Connected first install, interrupted model download, offline with/without model. |
| UI | Keyboard, VoiceOver, light/dark, enlarged text, small display. |
| Resources | Adequate disk, quota-limited store, concurrent LM Studio model, memory pressure, sleep/wake. |

Compatibility is a result, not inferred from meeting the OS minimum. No Windows, Intel or Linux claim until a corresponding matrix exists. Failures in conditional native tests block native integration claims even when the companion passes.

## Fixture catalogue and preparation

Prepare consented or public-domain recordings; record source, permission/license, speaker consent, language, duration, encoding and SHA-256 in a fixture manifest. Do not commit private speech. Human references are independently transcribed and adjudicated by a fluent reviewer. Keep punctuation-normalized scoring copies separate from the verbatim references. Reuse the same source recording for codec comparisons. The corpus should contain at least 30 minutes of English across 10 speakers, 15 minutes of French across 5 speakers, and 10 minutes of Japanese across 3 speakers; never infer general accuracy from one voice memo.

| ID | Required material |
| --- | --- |
| F01 | Clear English recordings, including a 60-second memo with names, an amount and a negation; matching human text. |
| F02–F04 | MP3, M4A/AAC and FLAC encodings of F01; verify actual codec/container. |
| F05 | French speech with accents and manual language reference. |
| F06 | English/French mixed speech and separate Japanese speech with fluent references. |
| F07 | Ten seconds of digital silence; available from the fixture generator. |
| F08 | Generated noise plus licensed music without speech; noise is available from the generator. |
| F09 | Speech with reproducible background noise, including an approximately 10 dB SNR set; preserve source reference. |
| F10 | Long speech with unique spoken markers straddling the actual engine chunk joins; include beginning/end markers. |
| F11 | Non-audio bytes renamed .mp3; available from the generator. |
| F12 | Truncated/corrupt audio with known valid original; available as a malformed WAV header from the generator. |
| F13 | Accented speech, speakers taking turns and overlap, numbers/negations; annotated critical words. |
| F14 | Equivalent mono/stereo/sample-rate variants; include speech on only one channel and antiphase channels. |

Boundary files must be independently confirmed valid. Prepare valid decodable audio exactly 500 MiB and one byte over (e.g. a valid RIFF padding chunk), and exactly 7200 seconds and one audio frame over. Do not use arbitrary junk padding that makes the input invalid for another reason. Check each limit independently while the other remains below its cap. A decoder-level fake is useful as an additional test, but does not replace at least one real near-limit job.

Prepare a test-only worker delay/failure/acceleration-failure mechanism during implementation. Isolate fault injection from production builds. Use workspace-contained quota limits for low-disk scenarios instead of filling the host disk. Where such hooks or environments are unavailable, mark the corresponding case BLOCKED with the reason.

## Measuring quality

WER = (substitutions + deletions + insertions) / reference word count. Normalize Unicode to NFC, lowercase and remove punctuation consistently; do not silently normalize away wrong numbers, negations or names. Compute corpus-level totals, not the unweighted average of per-clip scores. Keep both raw output and reviewed output; score raw recognition only. For Japanese use character error rate with a documented whitespace/punctuation policy. Report every language separately, along with worst clips and critical-word errors. Target clean English WER <=10%, French <=15%, noisy English <=25%, Japanese CER <=20%; these are proposed product gates, not measured Whisper claims. If the base model misses a gate, change the default or narrow the advertised capability, then rerun affected QA.

For LM Studio answers, separate transmission correctness from LLM quality. Exact reviewed prompt contents must match; an incorrect model answer with a correct prompt still fails the end-to-end experience check and is diagnosed as downstream model behavior. Never alter reference answers to match the model.

Measure inference time excluding download, and separately record total time from import to review. Use three cold and three warm runs; publish hardware/model/OS alongside medians and ranges. On minimum supported hardware the proposed 60-second clip target is <=60 seconds median warm inference, peak app RSS <=2 GiB, ordinary control latency <=200 ms, cancellation acknowledgement <=1 second and worker termination <=5 seconds. Observe a 2-hour job for bounded memory; do not extrapolate short-clip memory alone.

## Release gates and triage

P0 blocks basic correctness, privacy, data preservation or core workflow. P1 covers supported quality, usability and reliability promises. Both priorities must PASS for the chosen scope; no implied waivers. A companion release runs `--release`; a native release additionally runs `--release --native`. Future cases do not gate current scope. For each advertised environment, attach a passing ledger, installer identity and signed test summary. No open data-loss, silent-upload or wrong-chat defects are acceptable.

Smoke set after every candidate: QA-001, 008, 013, 020, 022–024, 029, 034, 037 and 043. Run the full baseline before release. Run native cases after every supported LM Studio upgrade if native integration is offered. Run exploratory sessions around fast repeated actions, unusual filenames, ambiguous language, accessibility and low-resource recovery; convert new failures into regression cases.

Novice study: recruit five people who have not developed plugins. Ask them to install, transcribe a memo, fix an amount and use it in LM Studio. Do not coach; record active time separately from download time, misclicks, recovery attempts and whether they understand where their data is stored. Pass at least four unaided completions and no lost text. Interview failures before adding more settings.

## Bug report template

Record case ID, severity, exact versions/hardware, fixture ID/hash, reproduction steps, expected versus actual behavior, frequency, sanitized evidence paths, data-loss/privacy impact, workaround and fix commit. A screenshot alone is insufficient evidence of transcription accuracy or network privacy. Retest the original case and related flows after a fix.
