# Reference review

Reviewed 2026-09-13. These are README/documentation findings, not execution results. Repository update ages were not assumed from the request: the VectorDB page advertises a September 13, 2025 release, so “all last updated two years ago” is not supported. Exact current commits and compatibility need pinning during implementation.

| Reference | Relevant idea | Simplification for this proposal |
| --- | --- | --- |
| [VideotronicMaker/LM-Studio-Voice-Conversation](https://github.com/VideotronicMaker/LM-Studio-Voice-Conversation) | Whisper with local LLM voice interaction; README uses Conda, Python and a launch script and notes compatibility caveats. | Keep local transcription; replace developer setup with a packaged app and omit voice playback/live conversation. |
| [BBC-Esq/VectorDB-Plugin](https://github.com/BBC-Esq/VectorDB-Plugin) (redirected from the supplied URL) | Audio transcription feeds document retrieval. README specifies Python, Git/LFS, Pandoc and compiler prerequisites, with Windows setup. | Omit embeddings, chunk databases, backend selectors and document search. |
| [Andi-wink/Whisper-AI-transcription-LMStudio-formatting](https://github.com/Andi-wink/Whisper-AI-transcription-LMStudio-formatting) | Python/Tkinter recording, Whisper Large v3, text refinement and clipboard integration. | Keep an editable transcript; make rewriting an explicit later action and avoid reading clipboard content automatically. |

## Current integration evidence

[LM Studio plugin documentation](https://lmstudio.ai/docs/typescript/plugins) describes JavaScript/TypeScript hooks and an included Node runtime. Its creation walkthrough remains incomplete. This is evidence of an extension mechanism, not proof of a polished audio-file installation flow.

[Prompt preprocessors](https://lmstudio.ai/docs/typescript/plugins/prompt-preprocessor) modify the current user message after Send and persist that modification to history. This could eventually deliver transcript context in-app. It does not by itself prove access to arbitrary audio attachments or editable composer insertion. File access, native runtime packaging, cancellation and distribution remain spike questions. Existing image/file attachments must survive any transformation.

[MCP through the API](https://lmstudio.ai/docs/developer/core/mcp) is documented for LM Studio 0.4.0+. It exposes model-callable tools. It does not establish that an API conversation appears in the user's desktop chat or that tool output becomes editable composer text. An MCP-first approach adds setup and model-dependent invocation, so it is not the baseline.

[whisper.cpp](https://github.com/ggml-org/whisper.cpp) supplies a local Whisper runtime with CPU support and Apple Silicon acceleration. Its CLI guidance calls for decoded PCM audio, so accepting an MP3 extension alone is insufficient: the app needs a validated decoder. Proposed macOS implementation: SwiftUI, platform audio decoding, and a pinned whisper.cpp library. This is an engineering recommendation, not a measured performance result.

## Integration spike: evidence required before claiming a native add-on

On an exact recorded LM Studio build, demonstrate: user-selected audio access; a packaged speech runtime without user-installed developer tools; download management; progress and cancellation; preservation of original text and attachments; transcript presentation in history; plugin install/update/remove without a terminal; operation with a non-tool-calling text model. Record logs and screenshots. Also investigate whether a supported editable composer API exists. If it does not, label preprocessor behavior as “transcribe on send,” never “insert into draft.”

The companion workflow can ship independently. The original embedded-add-on objective remains unfulfilled until the conditional native acceptance suite passes. Do not advertise native integration based only on a successful SDK example.
