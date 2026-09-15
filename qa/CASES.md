# QA acceptance cases

Generated from `cases.json`; JSON is the source of truth. Every case is NOT_RUN initially. Preconditions include fixtures that must be prepared per PLAN.md. Baseline, native and future scopes are separate release decisions.

## QA-001 — Clean installation

P0 · baseline · UC-01 · R01

**Preconditions:** Clean supported Mac; signed candidate installer; no developer tools

1. Install using published instructions.
2. open app.
3. download recommended model.
4. reach Ready.

**Pass condition:** No terminal or API key needed; no unhandled security dialog; exact version recorded

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-002 — Novice setup and first prompt

P1 · baseline · UC-01 · R01

**Preconditions:** Five casual participants; F01; LM Studio installed

1. Give installer and one-page instructions.
2. observe without coaching through paste and send.

**Pass condition:** At least 4 of 5 complete unaided; median active setup <=5 minutes excluding measured download; zero lost drafts

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-003 — First launch offline

P0 · baseline · UC-03 · R03

**Preconditions:** Clean model store; network disconnected

1. Open app.
2. start download.
3. restore network.
4. Retry.

**Pass condition:** Plain internet-needed message; no endless spinner; recovery reaches Ready

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-004 — Interrupted model download

P0 · baseline · UC-03 · R03

**Preconditions:** Connected network; empty model store

1. Start download.
2. interrupt connection at mid-download.
3. reopen.
4. Retry.

**Pass condition:** Partial file is never activated; resumed or restarted download verifies before use

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-005 — Corrupt model

P0 · baseline · UC-03 · R03

**Preconditions:** QA-controlled downloaded artifact with wrong hash

1. Attempt model activation.
2. select Retry with valid artifact.

**Pass condition:** Mismatch blocks inference; clear repair action; valid retry succeeds

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-006 — Insufficient model storage

P1 · baseline · UC-03 · R03

**Preconditions:** QA quota-limited workspace store below declared requirement

1. Start model download.
2. free space.
3. Retry.

**Pass condition:** Space requirement and failure explained; no partial active model; recovery works

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-007 — Cancel download

P1 · baseline · UC-03 · R03

**Preconditions:** Empty model store

1. Start download.
2. Cancel twice.
3. reopen app.

**Pass condition:** Cancellation is idempotent; no active partial model; download can restart

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-008 — Choose supported formats

P0 · baseline · UC-02 · R02

**Preconditions:** F01 and equivalent F02-F04 encodings

1. Choose each WAV/MP3/M4A/FLAC file.
2. transcribe.
3. compare content.

**Pass condition:** Each advertised format decodes and produces equivalent speech content without a codec installation

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-009 — Drop versus picker

P1 · baseline · UC-02 · R02

**Preconditions:** F01 in folder with spaces and Unicode name

1. Import by picker.
2. clear.
3. import by drag/drop.

**Pass condition:** Same filename, duration and transcript; Unicode preserved

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-010 — Misleading extension

P0 · baseline · UC-02 · R02

**Preconditions:** F11 non-audio renamed .mp3

1. Choose file and transcribe.

**Pass condition:** Content rejected with usable explanation; no crash or false completion

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-011 — Multiple-file drop

P1 · baseline · UC-02 · R02

**Preconditions:** F01 and F05

1. Drop both together.

**Pass condition:** Explains one-file limit; no silent processing of a random file

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-012 — Missing or denied source

P0 · baseline · UC-02 · R02

**Preconditions:** F01 selected; test source subsequently moved or permission denied

1. Select then move/deny source.
2. start job.
3. choose accessible replacement.

**Pass condition:** Actionable read error; replacement succeeds; unrelated files untouched

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-013 — Clean speech accuracy

P0 · baseline · UC-04 · R04

**Preconditions:** F01 with human reference; exact model hash recorded

1. Transcribe.
2. independently compare raw output using defined WER procedure.

**Pass condition:** Clean English aggregate WER <=10%; actual substitutions/deletions/insertions recorded

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-014 — Silent input

P0 · baseline · UC-04 · R04

**Preconditions:** F07 silence

1. Transcribe three times.
2. review all outputs.

**Pass condition:** No speech detected; no fabricated sentence; Copy disabled for empty output

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-015 — Music and noise without speech

P1 · baseline · UC-04 · R04

**Preconditions:** F08

1. Transcribe each sample.

**Pass condition:** No plausible fabricated speech presented as valid transcript; no hang

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-016 — Noisy speech

P1 · baseline · UC-04 · R04

**Preconditions:** F09 with human reference

1. Transcribe and score raw text.
2. inspect warning.

**Pass condition:** Aggregate WER <=25%; review notice available; no omission of whole speech sections

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-017 — French transcription

P0 · baseline · UC-05 · R04

**Preconditions:** F05 French with accents

1. Transcribe with Auto then French override.
2. compare human reference.

**Pass condition:** Source language retained; French aggregate WER <=15%; accents survive review/copy

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-018 — Wrong language recovery

P1 · baseline · UC-05 · R04

**Preconditions:** F05 with deliberately wrong language setting

1. Transcribe.
2. switch to French.
3. Retry.

**Pass condition:** New selection governs retry; previous language output does not append

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-019 — Mixed and non-Latin language

P1 · baseline · UC-05 · R04

**Preconditions:** F06 mixed speech and Japanese samples with references

1. Use Auto and override where applicable.
2. review with fluent speaker.

**Pass condition:** No hidden English translation; Japanese CER <=20%; mixed-language omissions explicitly assessed

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-020 — Edit and copy exact text

P0 · baseline · UC-06 · R05

**Preconditions:** Completed F01 transcript

1. Replace a name.
2. add emoji and blank lines.
3. Copy.
4. paste into plain editor.

**Pass condition:** Clipboard equals edited text exactly including Unicode and line breaks

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-021 — Reset and undo

P1 · baseline · UC-06 · R05

**Preconditions:** Edited transcript

1. Undo/redo edits.
2. Reset then Cancel.
3. Reset then confirm.

**Pass condition:** Cancel preserves edits; confirmed reset restores raw recognition text only

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-022 — End-to-end LM Studio prompt

P0 · baseline · UC-07 · R06

**Preconditions:** F01; supported LM Studio build; loaded text model

1. Transcribe.
2. correct amount to 42.
3. Copy.
4. paste.
5. ask what amount was stated.
6. Send.

**Pass condition:** Prompt visibly contains reviewed text once; model receives text and answers 42; capture prompt and response

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-023 — Preserve an existing prompt

P0 · baseline · UC-07 · R06

**Preconditions:** LM Studio composer contains BEFORE and AFTER

1. Place caret between words.
2. paste reviewed transcript.
3. inspect before Send.

**Pass condition:** Existing text outside selected range remains; companion never sends automatically

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-024 — Correct chat ownership

P0 · baseline · UC-07 · R06

**Preconditions:** Two LM Studio chats with distinct draft markers

1. Copy transcript.
2. choose second chat.
3. paste.
4. inspect first chat.

**Pass condition:** Only user-selected second draft changes; no automatic cross-chat mutation

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-025 — LM Studio closed

P1 · baseline · UC-07 · R06

**Preconditions:** Completed transcript; LM Studio closed

1. Copy and Save.
2. launch LM Studio.
3. paste.

**Pass condition:** Transcript remains usable; no LM Studio server requirement

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-026 — Clipboard changes require action

P0 · baseline · UC-07 · R06

**Preconditions:** Clipboard has synthetic sentinel; F01

1. Transcribe and edit without copying.
2. inspect clipboard.
3. then press Copy.

**Pass condition:** Sentinel stays until explicit Copy; no automatic clipboard reading or replacement

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-027 — UTF-8 export

P0 · baseline · UC-08 · R05

**Preconditions:** Edited transcript with accents, emoji and blank lines

1. Save .txt.
2. reopen in another editor.
3. compare.

**Pass condition:** Exact edited text preserved; original audio unchanged

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-028 — Save denied and overwrite cancel

P1 · baseline · UC-08 · R05

**Preconditions:** Existing output file; unwritable test directory

1. Save over file then cancel.
2. attempt denied destination.
3. choose valid destination.

**Pass condition:** Existing file unchanged on cancel; error preserves draft; valid save succeeds

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-029 — Cancel decoding and inference

P0 · baseline · UC-09 · R07

**Preconditions:** F10 long recording

1. Cancel once during decoding and once during inference.
2. Retry after each.

**Pass condition:** UI acknowledges within 1 second; worker stops within 5 seconds; no cancelled transcript is published

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-030 — Rapid clicks and late completion

P0 · baseline · UC-09 · R07

**Preconditions:** F10 and F01; worker-delay test hook

1. Double-click Transcribe.
2. cancel F10.
3. start F01.
4. release delayed F10 result.

**Pass condition:** One active job; output belongs only to F01; no duplicate insertion

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-031 — File size boundary

P0 · baseline · UC-10 · R10

**Preconditions:** Valid audio fixtures at 500 MiB and one byte above

1. Import each.
2. observe validation before inference.

**Pass condition:** 500 MiB allowed if other limits pass; larger file rejected before inference

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-032 — Duration boundary

P0 · baseline · UC-10 · R10

**Preconditions:** Valid audio at 7200 seconds and one audio frame above

1. Import each.
2. inspect decoded-duration validation.

**Pass condition:** 7200 seconds allowed; longer rejected; no dependence on misleading metadata alone

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-033 — Chunk continuity

P0 · baseline · UC-10 · R10

**Preconditions:** F10 with unique spoken markers around every chunk join

1. Transcribe.
2. compare markers and start/end against reference.

**Pass condition:** No missing or duplicated join phrases; final marker present; order retained

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-034 — Offline complete workflow

P0 · baseline · UC-11 · R08

**Preconditions:** Installed model; F01; network disabled

1. Restart.
2. transcribe.
3. edit.
4. copy.
5. save.

**Pass condition:** All steps work offline without remote-service retries

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-035 — Worker failure and retry

P0 · baseline · UC-12 · R07

**Preconditions:** Reviewed draft saved/retained; QA worker-failure hook

1. Attempt replacement.
2. provoke worker exit.
3. Retry.

**Pass condition:** Stage-specific error; retained draft intact; retry creates one fresh result

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-036 — Damaged audio recovery

P1 · baseline · UC-12 · R07

**Preconditions:** F12 truncated file and F01

1. Import damaged file.
2. recover by choosing F01.

**Pass condition:** Decoder fails clearly or flags partial decode; no silent complete transcript; next job succeeds

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-037 — Keyboard-only workflow

P0 · baseline · UC-13 · R09

**Preconditions:** F01; pointer unused

1. Tab through import/options/transcribe/cancel/review/copy/save.

**Pass condition:** Logical order; visible focus; all actions reachable; no keyboard trap

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-038 — VoiceOver workflow

P0 · baseline · UC-13 · R09

**Preconditions:** VoiceOver enabled; F01

1. Navigate controls.
2. run job.
3. edit and copy.
4. provoke invalid file.

**Pass condition:** Names/roles and progress/error states spoken; no repeated announcement flood; text editable

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-039 — Scaling and visual accessibility

P1 · baseline · UC-13 · R09

**Preconditions:** Small supported display; text enlarged; light/dark modes

1. Run full flow at 200% text size or OS equivalent.
2. inspect contrast.

**Pass condition:** No clipped essential controls; body text contrast >=4.5:1; controls/focus >=3:1; state not color-only

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-040 — Network privacy

P0 · baseline · UC-14 · R08

**Preconditions:** Installed model; synthetic private marker in F01; workspace-captured traffic

1. Monitor app process traffic while importing/transcribing/editing/copying.

**Pass condition:** No app-originated audio/text upload or telemetry; evidence distinguishes unrelated OS traffic

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-041 — Diagnostic redaction

P0 · baseline · UC-14 · R08

**Preconditions:** Synthetic unique marker in filename and transcript

1. Complete then fail job.
2. export diagnostics.
3. search for marker and full path.

**Pass condition:** No transcript, audio, clipboard content or sensitive source path in logs

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-042 — Clear session semantics

P0 · baseline · UC-14 · R08

**Preconditions:** Transcript copied, exported and pasted into LM Studio

1. Clear app session.
2. inspect app.
3. inspect external copies.

**Pass condition:** App view clears; explains external copies remain; no false all-copies-deleted claim

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-043 — Quit with unsaved text

P0 · baseline · UC-15 · R11

**Preconditions:** Edited unsaved transcript

1. Quit and Cancel.
2. repeat with Save.
3. repeat with Discard.

**Pass condition:** Cancel returns intact draft; Save handles errors before quitting; Discard requires explicit choice

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-044 — Crash cleanup

P0 · baseline · UC-15 · R11

**Preconditions:** F10 active; workspace-contained QA storage

1. Force-stop candidate process.
2. restart.
3. inspect intermediate files.

**Pass condition:** Stale decoded audio removed; original untouched; no unexplained transcript persistence

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-045 — Sleep and wake

P1 · baseline · UC-15 · R11

**Preconditions:** F10 running

1. Sleep machine.
2. wake.
3. wait for job or documented failure.

**Pass condition:** No duplicate completion or hang; progress recovers or actionable Retry appears

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-046 — Upgrade and rollback

P0 · baseline · UC-16 · R11

**Preconditions:** Previous candidate with installed model; new signed candidate

1. Upgrade.
2. transcribe.
3. simulate interrupted update in disposable test install.

**Pass condition:** Model remains valid; working version retained/recoverable; no user file loss

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-047 — Uninstall cleanup

P0 · baseline · UC-16 · R11

**Preconditions:** App/model plus external source and export fixtures

1. Follow removal instructions.
2. retain model once then remove it on repeat.

**Pass condition:** Only chosen app-owned data removed; source and exports intact; residual storage documented

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-048 — Minimum hardware performance

P1 · baseline · UC-17 · R10

**Preconditions:** Supported lowest-spec machine; F01 60 seconds; cold and warm runs

1. Run 3 cold and 3 warm trials.
2. record timings, peak RSS and responsiveness.

**Pass condition:** Median warm inference <=60 seconds; app RSS <=2 GiB; controls respond <=200 ms; publish measured hardware

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-049 — Resource pressure

P0 · baseline · UC-17 · R10

**Preconditions:** F10; supported machine; controlled competing workload

1. Transcribe with LM Studio loaded.
2. induce memory pressure.
3. cancel.

**Pass condition:** No system exhaustion from unbounded buffers; clear failure/retry if needed; cancellation works

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-050 — Acceleration fallback

P1 · baseline · UC-17 · R10

**Preconditions:** QA switch causing accelerator initialization failure

1. Start job.
2. use CPU retry.
3. compare transcript.

**Pass condition:** Explains recovery; CPU job works without reinstall; no endless automatic loop

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-051 — Dirty draft replacement

P0 · baseline · UC-18 · R07

**Preconditions:** Edited F01; F05 ready to import

1. Choose new file.
2. Keep editing.
3. repeat and Discard.

**Pass condition:** Keep preserves text; Discard replaces only after explicit action; no accidental loss

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-052 — Repeated use and leaks

P1 · baseline · UC-18 · R07

**Preconditions:** F01; installed model

1. Run 20 transcribe/clear cycles.
2. compare post-idle resource baseline after cycles 2 and 20.

**Pass condition:** No accumulating temp audio; idle RSS growth <=100 MiB; all outputs remain correct

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-053 — Oversized prompt handoff

P0 · baseline · UC-19 · R06

**Preconditions:** Long reviewed text exceeding small LLM context

1. Copy.
2. paste into LM Studio.
3. attempt Send.
4. recover by splitting.

**Pass condition:** No companion truncation; full original retained; host error understood; shorter prompt works

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-054 — Native install and attachment access

P0 · native · UC-20 · R12

**Preconditions:** Proven native integration candidate; clean supported LM Studio

1. Install without terminal.
2. choose real audio through supported attachment flow.
3. transcribe.

**Pass condition:** Native audio path is genuinely accessible; runtime packaged; no undocumented manual setup

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-055 — Native history persistence

P0 · native · UC-20 · R12

**Preconditions:** Native candidate enabled; F01 plus typed instruction

1. Send through preprocessor.
2. inspect history.
3. disable plugin.
4. reopen chat.

**Pass condition:** Transcript and instruction persist once in correct chat; no re-transcription of prior turns

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-056 — Native cancellation and failure

P0 · native · UC-20 · R12

**Preconditions:** Native candidate; F10 and decoder-failure fixture

1. Send.
2. cancel during processing.
3. retry after failure.

**Pass condition:** No incomplete replacement prompt reaches model; original instruction remains recoverable

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-057 — Native attachment and chat preservation

P0 · native · UC-20 · R12

**Preconditions:** Native candidate; two chats; text plus image attachment plus audio

1. Transcribe audio in one chat.
2. inspect all message parts and other chat.

**Pass condition:** Original image/text preserved; only selected audio transformed; no cross-chat leakage

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-058 — Native compatibility upgrade

P0 · native · UC-20 · R12

**Preconditions:** Native candidate; exact current and prior supported LM Studio builds

1. Install and run native smoke on both.
2. disable/remove plugin.

**Pass condition:** Both pass or unsupported build clearly blocks activation; normal chat remains functional

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-059 — Native composer claim verification

P0 · native · UC-20 · R12

**Preconditions:** Candidate advertised as inserting editable draft text

1. Transcribe before Send.
2. inspect composer.
3. edit text.
4. confirm no request sent.

**Pass condition:** Editable text appears before Send through a supported API; otherwise claim must be removed

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-060 — Native plugin interaction

P1 · native · UC-20 · R12

**Preconditions:** Native candidate and another preprocessor enabled

1. Run both execution orders on text/image/audio message.
2. inspect output.

**Pass condition:** No duplicate transcript, lost attachment or order-dependent corruption

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-061 — Numbers accents and speakers

P1 · baseline · UC-04 · R04

**Preconditions:** F13 accented multi-speaker speech with numbers and negations

1. Transcribe.
2. human-review names, amounts, negations and overlap.

**Pass condition:** No invented speaker labels; error counts reported separately; review flow makes corrections possible

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-062 — Channel and sample-rate variants

P1 · baseline · UC-02 · R02

**Preconditions:** F14 same speech in mono/stereo at 16/44.1/48 kHz and antiphase stereo

1. Import and transcribe each.

**Pass condition:** No speed/pitch shift; speech survives downmix; content remains within clean accuracy threshold

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-063 — Offline model import

P1 · future · UC-11 · R08

**Preconditions:** Verified model file in workspace; disconnected network

1. Use documented local-model import if offered.
2. try invalid hash then valid file.

**Pass condition:** Invalid model rejected; valid file activates without network; otherwise feature remains unadvertised

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-064 — Native speech model selector after host fix

P0 · native · UC-20 · R12

**Preconditions:** Installed multi-model plugin; LM Studio build with bug #2365 resolved; two chats

1. Open WhisperBridge settings in chat A.
2. select a non-default model and language.
3. open chat B and keep defaults.
4. restart LM Studio and reopen both chats.

**Pass condition:** Selector shows friendly purpose, model, size, memory, and license details; each chat retains its own model and language after restart

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-065 — Selected model first-use download

P0 · native · UC-03 · R03

**Preconditions:** Selected model absent; adequate disk; network connected

1. Select a model without sending.
2. confirm no files or network activity.
3. attach audio and Send.
4. observe download progress and completion.

**Pass condition:** Selection is passive; Send checks disk, shows named percentage progress, verifies every file, and activates only the complete revision

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-066 — Multi-file download cancellation and retry

P0 · native · UC-03 · R03

**Preconditions:** Large multi-file MLX model absent; network connected

1. Start first-use audio Send.
2. cancel during a later file.
3. inspect model store.
4. retry Send.

**Pass condition:** No partial revision or prompt activates; staging data is cleaned; retry verifies one complete snapshot and transcribes once

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-067 — Offline cached model reuse

P0 · native · UC-11 · R08

**Preconditions:** At least one Whisper and one MLX model verified locally; network disconnected

1. Restart LM Studio offline.
2. send one audio prompt with each cached model.

**Pass condition:** Both complete without a download attempt or global cache access and produce one transcript each

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-068 — Model switching across concurrent chats

P0 · native · UC-20 · R12

**Preconditions:** Two chats; two verified models; distinct audio fixtures

1. Select different models in each chat.
2. send both audio prompts concurrently.
3. inspect status, transcript, and process cleanup.

**Pass condition:** Each chat uses its selected model; no duplicate download or cross-chat status/text; each helper exits and releases model memory

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-069 — Unsupported model language blocks early

P0 · native · UC-05 · R04

**Preconditions:** English-only Moonshine selected; French selected; Moonshine absent locally

1. Attach French audio and Send.

**Pass condition:** A compatibility error recommends Auto or a compatible profile before network, model download, or helper activity

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-070 — Enabled model quality matrix

P0 · native · UC-04 · R04

**Preconditions:** Every selectable checkpoint downloaded and hashed; licensed English and family-specific multilingual references

1. Run the 30-second English fixture on every selectable checkpoint.
2. run one non-English fixture per multilingual family.
3. score normalized raw output.

**Pass condition:** English WER <=20%; multilingual-family WER <=25%; exact revision, hash, transcript, and score recorded for every selector option

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-071 — Enabled model performance and release

P1 · native · UC-17 · R10

**Preconditions:** M4 Max reference host; every selectable checkpoint cached; 30-second fixture

1. Measure cold start, warm runtime, peak RSS, installed size, and helper exit for each model serially.

**Pass condition:** Every model is faster than real time on the reference host; helper exits after each prompt; recorded memory fits the selector recommendation

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-072 — Native context overflow with selected model

P0 · native · UC-20 · R12

**Preconditions:** Cached speech model; long fixture; small-context LM Studio text model; unrelated attachment

1. Send typed instruction, long audio, and unrelated attachment.
2. observe overflow.
3. switch to a larger-context text model and retry.

**Pass condition:** Overflow sends no prompt, consumes no attachment, and preserves instruction; retry inserts one transcript and retains the unrelated attachment

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-073 — Multi-model plugin update and storage retention

P0 · native · UC-16 · R11

**Preconditions:** Prior plugin installed with verified Whisper and MLX models; current candidate available

1. Update plugin.
2. restart LM Studio.
3. transcribe with both retained models.
4. remove one model through documented storage management.

**Pass condition:** Update reuses valid revisions offline; removed model alone is reclaimed and downloads again on later use; other models and chats remain intact

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-074 — Prompt directive selection and chat persistence

P0 · native · UC-20 · R12

**Preconditions:** Installed plugin on LM Studio 0.4.24; two chats; non-default model cached

1. In chat A, attach audio and send `/wb model=better language=en filename=off` plus an instruction.
2. Verify the command is absent from the transformed instruction and the visible settings line is correct.
3. Send later audio in chat A without a command, then send audio in chat B.

**Pass condition:** Chat A reuses its chosen settings; chat B uses defaults; no directive reaches the language model; each transcript identifies the resolved settings

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-075 — Application-wide default, restart, and reset

P0 · native · UC-20 · R11

**Preconditions:** Installed plugin; two chats; writable WhisperBridge data directory

1. Send attached audio with `/wb default model=smallest filename=off`.
2. Restart LM Studio and send command-free audio in a new chat.
3. Send attached audio with `/wb default reset`, restart, and test another new chat.

**Pass condition:** The saved default survives restart and applies across chats; reset restores Base/Auto/filename-on defaults; settings writes are complete and contain no partial files

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-076 — Invalid fallback command blocks early

P0 · native · UC-05 · R04

**Preconditions:** Installed plugin; selected model absent locally

1. Attach audio and try an unknown key, model, language, filename value, and gated model ID.

**Pass condition:** Each send gives a useful example and View README direction before settings writes, network, model download, helper launch, prompt mutation, or attachment consumption

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-077 — Failed global command preserves prior defaults

P0 · native · UC-20 · R11

**Preconditions:** Existing global default; cancellable download and context-overflow fixtures

1. Issue a different `/wb default ...` command and cancel its transcription.
2. Repeat with a transcription or context-validation failure.
3. Restart and transcribe without a command.

**Pass condition:** Failed or canceled sends do not replace the prior global settings; original text and attachments remain intact

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.

## QA-078 — Native selector and fallback parity

P1 · native · UC-20 · R12

**Preconditions:** LM Studio build with bug #2365 resolved; native configuration fields visible

1. Transcribe with a model/language/filename combination selected natively.
2. Repeat in another chat with the equivalent `/wb` directive.

**Pass condition:** Both paths resolve the same catalog model, helper request, transcript format, language behavior, and filename behavior

**Evidence:** Record candidate/OS/LM Studio/model versions, actual result, and workspace-relative screenshot/log/measurement paths.
