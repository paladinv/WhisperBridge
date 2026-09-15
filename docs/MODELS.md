# Speech model catalog

WhisperBridge stores a prompt-selected model choice in the resulting LM Studio chat history and can save application-wide defaults in `settings-v1.json` beside its model store. Changing a selection does not download anything. The audio Send validates language and disk space, downloads only the declared files into a staging directory, verifies their sizes and SHA-256 hashes, writes a revision receipt, atomically activates the model, transcribes, and exits the helper. A verified local model is reusable offline and across chats. LM Studio's native selector remains registered for use after [host bug #2365](https://github.com/lmstudio-ai/lmstudio-bug-tracker/issues/2365) is fixed.

## Available profiles

| Family | Selectable checkpoints | Language behavior | Approximate download | License |
| --- | --- | --- | ---: | --- |
| Whisper | Tiny Multilingual; Base Multilingual; Small English and Multilingual in Q5, Q8, and full; Medium English and Multilingual in Q5, Q8, and full; Large v1 full; Large v2 Q5/Q8/full; Large v3 Q5/full; Large v3 Turbo Q5/Q8/full | Automatic detection and 99-language selection for multilingual weights; English-only weights reject other explicit languages before download | 78 MB–3.10 GB | MIT |
| Moonshine | Tiny | English only | 110 MB | MIT |
| Parakeet | TDT 0.6B v3 MLX 8-bit | 25 European languages with detection | 909 MB | CC BY 4.0 |
| Cohere | Transcribe 2B MLX 4-bit | Arabic, Chinese, Dutch, English, French, German, Greek, Italian, Japanese, Korean, Polish, Portuguese, Spanish, Vietnamese | 1.51 GB | Apache 2.0 |
| Granite | Granite 4.0 1B Speech MLX 5-bit | English, French, German, Spanish, Portuguese, Japanese | 2.23 GB | Apache 2.0 |

Whisper Base Multilingual is the default. Q5 uses the least disk and memory within a Whisper size tier; Q8 trades more space for fidelity; full weights use the most space. Large v3 Turbo Q5 is the recommended larger model when accuracy matters but a 3.1 GB full checkpoint is undesirable.

## Pinned runtime and model sources

- `whisper.cpp` runtime: v1.9.1, commit `f049fff95a089aa9969deb009cdd4892b3e74916`.
- `mlx-audio-swift`: 0.1.3, commit `d302a5c6080d2bb97bae38c7418f82abb76013b6`.
- Whisper GGML files: `ggerganov/whisper.cpp` revision `5359861c739e955e79d9a303bcbc70fb988958b1`.
- Moonshine Tiny: revision `390624ed33d594443aa4aa221f5b9f283b545b5a`.
- Parakeet MLX 8-bit: revision `c890f9db34cd0b273cf5f47eab068e32e72cc868`.
- Cohere MLX 4-bit: revision `104bc4391b5b1a12b040859793d7148525e1a08c`.
- Granite MLX 5-bit: revision `371e6922faffba916e983e9c083049ad44536e94`.

The authoritative required-file sizes and SHA-256 values are in [`plugin/src/modelCatalog.ts`](../plugin/src/modelCatalog.ts). Only those runtime files are downloaded; model cards, demos, samples, and alternative weights are excluded.

## Gated adapters

MOSS Transcribe Diarize and Canary-Qwen adapters and catalog metadata are implemented but omitted from the selector. The reviewed MOSS 5-bit conversion fails MLX Audio Swift 0.1.3's VQ-adaptor layout validation. Canary-Qwen's exact 2.5B checkpoint still requires NeMo/PyTorch and has no verified native Swift conversion. They will become selectable only after a compatible pinned checkpoint passes download integrity, real transcription, cancellation, quality, performance, and LM Studio composer gates.

## Storage management

Models live at `~/Library/Application Support/LM Studio/WhisperBridge/models/<model-id>/<revision>/`. LM Studio's current declarative plugin configuration does not provide a model-delete action. Quit active transcription, remove a complete model-ID directory in Finder, and leave other WhisperBridge directories intact. Selecting that model later downloads and verifies it again.
