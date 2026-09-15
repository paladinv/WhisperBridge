# LM Studio integration feasibility and implementation plan

Reviewed 2026-09-14 against LM Studio 0.4.19+2 and the current official TypeScript plugin documentation.

## Implementation status

The repository now implements the TypeScript prompt preprocessor, per-chat model/language configuration, pinned multi-file model download and verification, versioned helper protocol, Apple silicon helper target, packaged `whisper.cpp` and MLX Audio Swift runtimes, prompt transformation, failure-safe attachment consumption, progress, cancellation, focused automated tests, and development packaging workflow. The selector offers 23 official Whisper variants plus verified Moonshine, Parakeet, Cohere, and Granite checkpoints. MOSS and Canary-Qwen adapters remain gated for the reasons recorded in [the model catalog](MODELS.md).

SDK 1.4.0 confirms that an attached `FileHandle` exposes `getFilePath()`. The official `lms dev --install` flow has installed `paladinv/whisperbridge`, and LM Studio's server log confirms that the installed process connected and registered its prompt preprocessor. A headless SDK integration uploaded real audio through `client.files.prepareFile()`, resolved the LM Studio-managed path through `getFilePath()`, transcribed it, replaced the message, and consumed the handle. The native helper from the installed directory separately completed the same fixture with the expected transcript. Gates A, C, and D remain incomplete until the registered hook is exercised through the actual LM Studio composer and distributed through a no-terminal Hub flow. Gate B's functional and short-fixture timing portions pass on the recorded M4 Max environment; long-file memory and cancellation measurements remain pending.

## Decision

Build WhisperBridge as an LM Studio **prompt-preprocessor plugin**. The user attaches an audio file to the normal LM Studio composer, optionally types an instruction, and selects Send. WhisperBridge transcribes locally, consumes the audio attachment, and replaces the outgoing user message with the instruction plus a clearly delimited transcript. LM Studio then sends that transformed message to the selected model and stores it in chat history.

This is feasible in principle through LM Studio's supported plugin system. The official `rag-v1` plugin demonstrates that a prompt preprocessor can discover and consume attached files, show status inside LM Studio, observe cancellation, and replace the current user message. The remaining uncertainty is whether the current plugin file handle exposes audio bytes or a readable path and which local Whisper runtime can be packaged without a separate installer.

Do not modify LM Studio's Electron archive or inject controls into its signed application bundle. Such a patch would be version-fragile, invalidate the supported distribution boundary, and create an update and signing burden. Do not use MCP as the primary workflow: MCP tools are model-invoked, while audio-to-prompt conversion should happen predictably before inference.

## Intended user experience

1. Install WhisperBridge from LM Studio's Hub. During development, install it with `lms dev --install`.
2. In a normal LM Studio chat, attach one supported audio file.
3. Optionally type an instruction such as “Summarize this meeting and list decisions.”
4. Select Send. LM Studio shows `Transcribing locally…` with a cancel action.
5. WhisperBridge validates and decodes the file, runs Whisper locally, removes the binary attachment from the outgoing message, and inserts:

   ```text
   User request:
   Summarize this meeting and list decisions.

   Audio transcript (meeting.m4a):
   <audio-transcript>
   …recognized text…
   </audio-transcript>
   ```

6. The selected model receives that text, and the transformed message remains visible in LM Studio history.

Plugin settings expose only useful choices: speech model, automatic or explicit language, and whether to include the source filename. Model selection is per chat and passive; model download, validation, and storage are managed by the plugin on the next audio Send.

## Confirmed capabilities and limits

| Capability | Current evidence | Consequence |
| --- | --- | --- |
| Run code inside LM Studio | Official TypeScript plugin SDK and `lms dev` hot reload | A supported in-app implementation is available. The SDK is currently labeled beta/private beta. |
| Transform a prompt on Send | Prompt preprocessors receive and return the current `ChatMessage` | Transcription can be inserted before model inference and saved in history. |
| Work with attachments | Official `lmstudio/rag-v1` calls `getFiles` and `consumeFiles` | The normal composer can remain the entry point. Raw audio access still needs a spike. |
| Show in-app progress and cancel | The preprocessor controller exposes status and an abort signal | Long transcription does not need a second visible app. |
| Provide settings | Custom configuration schemas render settings in LM Studio | Language and model choices can use native plugin settings. |
| Install JavaScript dependencies | LM Studio installs locked npm dependencies | Casual users do not need Node.js, but package post-install scripts do not run. |
| Edit the draft before first inference | No documented composer/draft mutation hook | Version 1 should be described as **transcribe on send**. A review-before-send mode is conditional on a future or undiscovered supported hook. |
| Add a custom microphone/button to the composer | No documented arbitrary composer UI extension | Version 1 uses LM Studio's attachment control. Do not promise a custom button. |

## Runtime decision

Test runtime options in this order:

1. **Prompt preprocessor plus a bundled macOS helper executable.** Reuse the existing Swift audio validation/decoding and `whisper.cpp` engine behind a small command-line protocol. This is likely to provide the best Apple Silicon performance and reuse the implemented, tested core. It is the preferred route only if the plugin runner may launch a packaged executable and LM Studio Hub accepts, preserves, and updates native binaries.
2. **Prompt preprocessor plus a packaged WASM Whisper runtime.** Use this if process launch or native binary distribution is unavailable. Confirm Node runner support for the required WASM memory and threading features, and measure speed and memory before adopting it.
3. **Prompt preprocessor plus a background companion service.** This keeps the interaction inside LM Studio but requires a separately installed component. Treat it as a compatibility fallback, not the target product.

A native Node add-on is not the first choice. LM Studio does not run npm post-install scripts, so dependencies that compile or download a binary during installation will fail the casual-install requirement. A prebuilt add-on may be reconsidered only after testing architecture, ABI, signing, and Hub packaging.

The plugin/helper boundary should use a small versioned JSON protocol. Pass an authorized input handle or path, language, model path, and job ID. Return stage events, detected language, duration, and transcript. Send no transcript, private path, or audio data to diagnostic logs. Cancellation must stop decoding/inference and remove intermediates.

## Delivery plan and gates

### Phase 0 — SDK contract spike (1–2 engineering days)

- Scaffold a minimal TypeScript plugin with a locked dependency graph and run it using `lms dev` on LM Studio 0.4.19+2.
- Attach small WAV, M4A, MP3, AAC, and FLAC fixtures through the normal composer.
- Prove file MIME/name discovery, raw byte or readable path access, file consumption, status display, cancellation, and replacement of the current message.
- Verify that unrelated attachments and typed instructions are preserved exactly.
- Install and remove the development plugin from a clean LM Studio profile.

**Gate A:** proceed only when an attached audio file can be read and consumed through a documented plugin API and message replacement works with a non-tool-calling model. If raw audio access is unavailable, ask LM Studio for a supported file API; do not patch the application bundle.

### Phase 1 — transcription runtime spike (2–4 engineering days)

- Extract a headless adapter around the current Swift/`whisper.cpp` core without changing the native app behavior.
- Test whether the plugin runner can start and cancel the helper and whether Hub packaging retains its executable permissions and signature.
- If that fails, prototype the WASM runtime and compare wall time, peak memory, package size, and cancellation latency.
- Keep model files in plugin-managed storage; download atomically from a pinned manifest and verify size and SHA-256.

**Gate B:** a 3.1-second fixture must transcribe within the existing 15-second smoke budget on the supported baseline Mac; cancel must stop within two seconds; a repeat run must work offline; corrupt models and unsupported inputs must fail without sending a prompt. Record peak memory and confirm that the LM Studio UI remains responsive.

### Phase 2 — in-app vertical slice (3–5 engineering days)

- Implement audio detection, single-file policy, validation, model setup, local transcription, progress, cancellation, and transcript insertion.
- Add minimal native plugin configuration for language and model preset.
- Make preprocessing idempotent so retries or other preprocessors cannot duplicate transcript blocks.
- Handle empty speech, oversized files, context overflow guidance, multiple audio files, model download interruption, and LM Studio shutdown.
- Preserve the current companion implementation until this vertical slice reaches feature parity and rollback is proven.

**Gate C:** the selected model receives exactly the intended instruction and transcript, no audio content leaves the Mac after model download, no stale job modifies another chat, and failures leave the user's typed instruction intact.

### Phase 3 — casual installation and distribution (2–4 engineering days)

- Package the selected runtime, notices, pinned model manifest, and configuration with the plugin.
- Validate Hub/private-plugin publication, updates, uninstall, architecture handling, and native signing/notarization if a helper is used.
- Write a three-step install guide that requires no shell, Python, Homebrew, API key, or separately launched app.
- Retain a development guide for `lms dev --install`; this must not become the end-user installation path.

**Gate D:** a new user installs, downloads the recommended model, attaches audio, and receives a model response without opening Terminal. Update and uninstall leave LM Studio functional and remove only WhisperBridge-owned data according to the documented retention policy.

### Phase 4 — regression, performance, and release QA (3–5 engineering days)

- Map current core tests to the shared runtime and add plugin contract tests for message transformation, attachment preservation, retry idempotence, and cancellation.
- Run focused unit tests first, then the plugin integration set, performance tests separately and serially, and the full release milestone last.
- Execute the existing manual QA cases against the installed plugin. Add clean-install, plugin enable/disable, LM Studio update, simultaneous chats, preprocessor ordering, and helper crash cases.
- Test exact supported LM Studio builds, starting with 0.4.19+2 and the current release candidate at release time.
- Compare baseline LM Studio idle CPU/memory and prompt latency with the plugin disabled, enabled but idle, and transcribing.

**Release gate:** zero missing, unexpected, failed, or unrun selected cases; no measurable idle CPU activity attributable to WhisperBridge; no model-load or ordinary text-prompt latency regression when no audio is attached; recorded transcription time and peak memory stay within declared budgets. Manual cases remain pending until executed on the packaged plugin with licensed fixtures.

## Focused QA additions

| Area | Required checks |
| --- | --- |
| Ordinary prompts | Text-only Send bypasses WhisperBridge and produces byte-for-byte equivalent user content. Measure latency over repeated runs. |
| Attachments | One audio file is consumed; non-audio files and typed text are preserved; ambiguous or multiple audio inputs receive a clear action. |
| Chats | Two chats cannot receive each other's progress, transcript, model, language, or cancellation event. |
| Failure safety | Decoder, model, runtime, cancellation, and context-size failures do not send a partial or empty prompt. |
| Performance | Idle CPU is zero within measurement resolution; idle memory is bounded; UI stays responsive; helper terminates after work. |
| Privacy | After the verified model download, network-disabled transcription succeeds; logs contain no audio, transcript, or private source path. |
| Lifecycle | Enable, disable, update, LM Studio restart, helper crash, and uninstall are recoverable and leave normal chat unaffected. |
| Accessibility | Status and errors are announced, controls have names, and keyboard users can attach, cancel, and adjust settings. |

## Schedule and stopping rules

A decision-quality feasibility prototype should take about one week. A testable macOS beta should take roughly two to three weeks if the plugin SDK, raw attachment access, helper execution, and Hub packaging work as expected. These are engineering estimates, not release promises.

Stop the native-plugin route if LM Studio does not expose audio data to preprocessors, prohibits both packaged execution and an adequate WASM runtime, or cannot distribute the result without a separate technical installation. In that case, keep the existing companion app as the supported fallback and publish the missing capability request to LM Studio. Do not silently substitute an unsupported LM Studio patch.

## Source evidence

- [LM Studio TypeScript plugins](https://lmstudio.ai/docs/typescript/plugins)
- [`lms dev` development workflow](https://lmstudio.ai/docs/cli/develop-and-publish/dev)
- [Prompt preprocessors](https://lmstudio.ai/docs/typescript/plugins/prompt-preprocessor)
- [Official `rag-v1` prompt-preprocessor source](https://lmstudio.ai/lmstudio/rag-v1/files/src/promptPreprocessor.ts)
- [Custom plugin configuration](https://lmstudio.ai/docs/typescript/plugins/custom-configuration)
- [Plugin npm dependencies](https://lmstudio.ai/docs/typescript/plugins/dependencies)
- [Publishing plugins](https://lmstudio.ai/docs/typescript/plugins/publish-plugins)
- [LM Studio MCP support](https://lmstudio.ai/docs/app/mcp)
