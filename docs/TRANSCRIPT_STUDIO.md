# Transcript Studio architecture

WhisperBridge is a hybrid product. The LM Studio plugin remains the fast audio-to-prompt path. The native SwiftUI Transcript Studio owns long-lived transcripts, audio playback, search, editing, speaker correction, and exports because LM Studio does not currently expose a custom editor panel to plugins.

## Storage

`WhisperBridgeCore.TranscriptStore` owns `library-v1.sqlite3`, enables WAL, foreign keys, a five-second busy timeout, and transactional saves. It stores transcripts, managed audio, speakers, segments, words, decoding settings, and legacy archive metadata. FTS5 indexes active presentation text and speaker names. Search returns bounded snippets and never audio bytes or private filesystem paths.

Imported audio is SHA-256 addressed under `library/audio/<digest>.<extension>`. A copy is written to a unique partial path, hashed again, and atomically moved into place. Identical recordings share one asset. SQLite records are saved only after the audio copy and transcript succeed.

Recognition output remains in `rawText`. User edits, deleted segments, speaker assignments, and filler visibility are stored separately. Hiding fillers uses a conservative standalone list and does not destroy timing or raw text.

## Local diarization

FluidAudio 0.15.5 is pinned in `project.yml`. WhisperBridge supplies its own model directory and checks the full required asset set before loading. It never asks FluidAudio to use a default host-global cache. The feature is gated to macOS 15 or newer because FluidAudio documents a Core ML crash risk on macOS 14. Initial speaker assignment chooses the diarization interval with the greatest temporal overlap; users can correct it without rerunning inference.

Verified assets belong at:

```text
~/Library/Application Support/LM Studio/WhisperBridge/models/fluid-audio-diarization/0.15.5/
└── speaker-diarization-coreml/
```

The required compiled bundles inside `speaker-diarization-coreml/` are `Segmentation.mlmodelc`, `FBank.mlmodelc`, `Embedding.mlmodelc`, and `PldaRho.mlmodelc`, plus `plda-parameters.json`. FluidAudio is forced into offline mode before loading, so missing files cannot trigger an implicit download or host-global cache write. A release must ship catalog hashes and an installer before claiming one-click diarization setup; this implementation fails clearly when the verified set is absent.

## Protocol v3

The helper accepts v1 and v2 requests for compatibility and adds v3 fields for a time range, timestamp granularity, diarization, decoder options, and explicit library saving. Results contain duration, normalized text, segments, optional word timing, speakers, overlap flags, detected language, and the saved transcript ID.

`search_transcripts` and `get_transcript_excerpt` use protocol-v3 read-only operations. Responses are capped and contain no audio or local paths.

## Archive compatibility

A `.tst` import accepts the STTTTS v1 ZIP shape (`manifest.json`, `transcript.txt`, optional `media/`, optional `exports/`). Export adds `format_version: 2` and `segments.json`. Legacy readers retain transcript/media compatibility while WhisperBridge preserves speakers, words, edits, timing, and decoder settings.

Before reading, WhisperBridge rejects absolute or traversal paths, backslashes, symlinks/directories, duplicate entries, excessive entry counts, large individual entries, large expanded archives, and unsafe compression ratios. Imports are staged inside the WhisperBridge data directory and create no partial transcript record.
