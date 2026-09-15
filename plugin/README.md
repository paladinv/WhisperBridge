# WhisperBridge LM Studio plugin

WhisperBridge is a prompt preprocessor for LM Studio. Attach one WAV, MP3, M4A, AAC, or FLAC file to a chat and select Send. The plugin transcribes the file locally and replaces the attachment with a clearly delimited transcript before the selected language model runs.

After installation, open a Chat and use the **Integrations** panel in the right sidebar (hammer icon) to enable `paladinv/whisperbridge` for that chat. Expand its row to choose the language and whether to include the filename. **Settings → Integrations → Tool Call Confirmation** only manages approval rules for model-callable tools, so WhisperBridge is not listed there.

Disable LM Studio's bundled RAG integration for chats where you attach audio, or place WhisperBridge before RAG if ordering controls are available. Current beta versions may otherwise attempt document retrieval on the audio before WhisperBridge runs.

The current source package targets Apple silicon Macs. End users should install a packaged release through LM Studio. Development installation is documented in [`../docs/PLUGIN_DEVELOPMENT.md`](../docs/PLUGIN_DEVELOPMENT.md).
