# WhisperBridge LM Studio plugin

WhisperBridge is a prompt preprocessor for LM Studio. Attach one WAV, MP3, M4A, AAC, or FLAC file to a chat and select Send. The plugin transcribes the file locally and replaces the attachment with a clearly delimited transcript before the selected language model runs.

After installation, open a Chat and use the **Integrations** panel in the right sidebar (hammer icon) to enable `paladinv/whisperbridge` for that chat. **Settings → Integrations → Tool Call Confirmation** only manages approval rules for model-callable tools, so WhisperBridge is not listed there.

## Choose a speech model

LM Studio 0.4.23 and 0.4.24 have a [host UI bug](https://github.com/lmstudio-ai/lmstudio-bug-tracker/issues/2365) that hides plugin configuration fields. Put one of these commands on the first line of a prompt that has one audio file attached:

```text
/wb model=better language=auto filename=on
Summarize this recording.
```

WhisperBridge removes the command before the language model sees the instruction. Later audio messages in that chat inherit the selected settings. The completed message shows the model, language, and filename behavior that were used.

| Model value | Profile |
| --- | --- |
| `everyday` | Whisper Base Multilingual; default |
| `smallest` | Whisper Tiny Multilingual |
| `better` | Whisper Small Multilingual |
| `best` | Whisper Large v3 Turbo Q5 |
| `fast-english` | Moonshine Tiny; English only |
| `european` | Parakeet TDT 0.6B v3 |
| `high-accuracy` | Cohere Transcribe 2B |
| `granite` | Granite 4.0 Speech |

Every available model ID from the project model catalog is also accepted, including all larger Whisper variants. Use ISO language codes such as `en`, `fr`, `de`, `es`, `pt`, or `ja`; use `auto` for automatic detection. Set `filename=on` or `filename=off`.

Larger Whisper model IDs: `whisper-small-q5`, `whisper-small-q8`, `whisper-small-english-q5`, `whisper-small-english-q8`, `whisper-small-english`, `whisper-medium-multilingual`, `whisper-medium-q5`, `whisper-medium-q8`, `whisper-medium-english-q5`, `whisper-medium-english-q8`, `whisper-medium-english`, `whisper-large-v1-multilingual`, `whisper-large-v2-multilingual`, `whisper-large-v2-q5`, `whisper-large-v2-q8`, `whisper-large-v3-multilingual`, `whisper-large-v3-q5`, `whisper-large-v3-turbo-full`, and `whisper-large-v3-turbo-q8`.

| Command | Effect |
| --- | --- |
| `/wb model=better` | Change this chat, starting with the attached audio |
| `/wb default model=best` | Save the application-wide default and apply it now |
| `/wb reset` | Make this chat inherit current defaults |
| `/wb default reset` | Clear application-wide saved defaults |

Commands are accepted only with an audio attachment. Text-only prompts are never treated as WhisperBridge commands. Choosing a model starts no network activity by itself; its verified download begins as part of that audio Send.

Disable LM Studio's bundled RAG integration for chats where you attach audio, or place WhisperBridge before RAG if ordering controls are available. Current beta versions may otherwise attempt document retrieval on the audio before WhisperBridge runs.

The current source package targets Apple silicon Macs. End users should install a packaged release through LM Studio. Development installation is documented in [`../docs/PLUGIN_DEVELOPMENT.md`](../docs/PLUGIN_DEVELOPMENT.md).
