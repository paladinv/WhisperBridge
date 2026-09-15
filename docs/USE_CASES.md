# Use-case catalogue

All flows below are proposed acceptance contracts. UC-20 is conditional; UC-01 through UC-19 define the companion baseline. Shared actors are the user, local transcription worker and (for handoff) LM Studio. Tests are linked by stable IDs in qa/cases.json.

## UC-01: First-time setup

- Requirement: R01
- Preconditions / trigger: A casual user opens the installer on a supported clean Mac.
- Main flow: Install, open, accept the model download, and reach Ready.
- Exceptions: No developer tooling is required; interrupted setup offers Retry.
- Success postcondition: Ready with a verified model; no audio has been accessed.

## UC-02: Choose a recording

- Requirement: R02
- Preconditions / trigger: The app is Ready and the user has a supported recording.
- Main flow: Choose a file or drop it onto the window; review filename and duration.
- Exceptions: Invalid, inaccessible or multiple files receive actionable feedback.
- Success postcondition: Exactly one validated source is selected; original is unchanged.

## UC-03: Download or repair the model

- Requirement: R03
- Preconditions / trigger: A model is missing, incomplete or invalid.
- Main flow: Display storage/download information, download, verify and activate.
- Exceptions: Offline, cancellation, low disk or hash mismatch never activates partial data.
- Success postcondition: Ready only when a complete verified model exists.

## UC-04: Transcribe a voice memo

- Requirement: R04
- Preconditions / trigger: A valid recording and local model are ready.
- Main flow: Select Transcribe, observe progress, then review the text.
- Exceptions: Silent or damaged audio receives a clear result without invented success.
- Success postcondition: Raw recognized text is available for editing.

## UC-05: Transcribe another language

- Requirement: R04
- Preconditions / trigger: A multilingual model and non-English recording are ready.
- Main flow: Use Auto first; select the spoken language and retry if necessary.
- Exceptions: Unsupported selection is rejected; mixed language is reviewed manually.
- Success postcondition: Output remains in the source language, without hidden translation.

## UC-06: Review and correct

- Requirement: R05
- Preconditions / trigger: Recognition has completed.
- Main flow: Edit names and numbers, undo changes, optionally reset to raw text.
- Exceptions: Reset or replacement of dirty text requires confirmation.
- Success postcondition: The reviewed text is distinct from the original recognition output.

## UC-07: Use text in an LM Studio prompt

- Requirement: R06
- Preconditions / trigger: A transcript exists and LM Studio has an editable chat.
- Main flow: Copy, select the prompt location, paste, add an instruction, then send.
- Exceptions: LM Studio being absent or unavailable does not lose the transcript.
- Success postcondition: Only the user-selected text is pasted; sending remains a user action.

## UC-08: Save or reuse a transcript

- Requirement: R05
- Preconditions / trigger: Reviewed text exists.
- Main flow: Save UTF-8 text or copy it into another prompt.
- Exceptions: Denied write or overwrite cancellation leaves the draft intact.
- Success postcondition: Export equals edited text; source audio remains unchanged.

## UC-09: Cancel and retry

- Requirement: R07
- Preconditions / trigger: Download, decoding or inference is running.
- Main flow: Cancel; wait for acknowledgement; retry the selected job.
- Exceptions: Repeated clicks or late worker results cannot corrupt a new job.
- Success postcondition: No cancelled result is inserted; controls recover.

## UC-10: Handle a long recording

- Requirement: R10
- Preconditions / trigger: A source is near a size or duration limit.
- Main flow: Validate limits, transcribe with bounded memory, review chunk joins.
- Exceptions: Over-limit input is rejected; text is never silently truncated.
- Success postcondition: Complete ordered transcript or explicit failure with recoverable state.

## UC-11: Work offline

- Requirement: R08
- Preconditions / trigger: The model is installed and network is unavailable.
- Main flow: Open app, transcribe, review, copy and save.
- Exceptions: First use without a model explains the download requirement.
- Success postcondition: Audio and transcript need no remote service.

## UC-12: Handle failure without losing work

- Requirement: R07
- Preconditions / trigger: A previous reviewed draft exists.
- Main flow: Save or explicitly discard before a replacement job; provoke a worker failure.
- Exceptions: Errors name the failed stage and offer Retry without stale output.
- Success postcondition: Retained work remains intact; no false success.

## UC-13: Use assistive technology

- Requirement: R09
- Preconditions / trigger: The user relies on keyboard or VoiceOver.
- Main flow: Import, transcribe, cancel, edit, copy and save through accessible controls.
- Exceptions: Errors and progress announcements do not trap focus or flood speech.
- Success postcondition: The same workflow is usable without a pointer.

## UC-14: Protect private recordings

- Requirement: R08
- Preconditions / trigger: The user processes sensitive but authorized audio.
- Main flow: Keep processing local; inspect diagnostics; clear the session.
- Exceptions: Explain clipboard, exports and LM Studio history as separate copies.
- Success postcondition: No silent upload or private content in app logs.

## UC-15: Quit and reopen

- Requirement: R11
- Preconditions / trigger: A job or unsaved transcript exists.
- Main flow: Quit, choose Save/Discard/Cancel; reopen after normal or forced exit.
- Exceptions: Crash leftovers are removed; no private draft recovery is assumed.
- Success postcondition: App starts in a consistent state; original source survives.

## UC-16: Update or uninstall

- Requirement: R11
- Preconditions / trigger: An installed version and model exist.
- Main flow: Update atomically, or remove the app and choose whether to remove its model.
- Exceptions: Failed update preserves working version; original recordings are never removed.
- Success postcondition: Predictable version/data state and clear cleanup instructions.

## UC-17: Use a modest computer

- Requirement: R10
- Preconditions / trigger: Supported minimum hardware is under normal load.
- Main flow: Run transcription while interacting with the window and LM Studio.
- Exceptions: Memory pressure or acceleration failure yields bounded recovery.
- Success postcondition: App remains responsive; no unsupported speed promise.

## UC-18: Replace or repeat a job

- Requirement: R07
- Preconditions / trigger: A current selection or reviewed draft exists.
- Main flow: Choose another file or transcribe the same one again.
- Exceptions: Multiple launches, dirty edits and stale completion events are controlled.
- Success postcondition: Text belongs only to the current job and selection.

## UC-19: Avoid an oversized LLM prompt

- Requirement: R06
- Preconditions / trigger: The transcript is larger than the selected LLM can accept.
- Main flow: Copy and paste; observe host limit; shorten or split while retaining the original.
- Exceptions: Companion cannot certify the host context budget; no silent truncation.
- Success postcondition: User retains the full text and chooses what to send.

## UC-20: Use native transcription in LM Studio (conditional)

- Requirement: R12
- Preconditions / trigger: A supported, installed integration is proven on an exact host version.
- Main flow: Select audio through the supported flow, optionally choose chat or global speech settings with the documented first-line command, and run the hook.
- Exceptions: Cancellation, host upgrade or unsupported attachments preserve message integrity.
- Success postcondition: Transcript and resolved settings appear in the correct chat; later audio inherits the intended chat/global choice; composer insertion is claimed only if separately verified.
