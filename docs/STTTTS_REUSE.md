# STTTTS reuse record

WhisperBridge ports selected transcription behavior from the user-owned STTTTS repository at commit `bbb51c5` (`Implement major feature expansion and supporting tests`). The user explicitly authorized this reuse for the public WhisperBridge repository on 2026-09-15.

Reused behavior includes subtitle timestamp parsing and serialization, custom export placeholders, greedy/beam controls, temporal-overlap speaker assignment, compact display, conservative filler cleanup, manual speaker labeling, transcript search expectations, and the `.tst` project layout. The implementation is rewritten in Swift around structured segments and SQLite rather than copied as a Python runtime dependency.

WhisperBridge does not include PySide6, PyInstaller, faster-whisper, Torch, Transformers, ffmpeg, pyannote, STTTTS cache paths, or STTTTS working-tree changes. The source repository had unrelated uncommitted changes during review and was not modified.

`.tst` compatibility keeps the legacy `manifest.json`, `transcript.txt`, and optional `media/` layout. WhisperBridge adds `format_version: 2` and `segments.json`; older STTTTS builds can ignore those additions. Imports validate archive paths, entry types, sizes, counts, and compression ratios before writing library data.
