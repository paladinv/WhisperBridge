# Third-party notices

WhisperBridge includes the `whisper` framework from [whisper.cpp v1.9.1](https://github.com/ggml-org/whisper.cpp/releases/tag/v1.9.1), commit `f049fff95a089aa9969deb009cdd4892b3e74916`. The downloaded release archive was verified with SHA-256 `8c3ecbe73f48b0cb9318fc3058264f951ab336fd530e82c4ccdd2298d1311a4c`.

whisper.cpp is distributed under the MIT License:

Copyright (c) 2023-2026 The ggml authors

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

The Whisper model weights are downloaded separately at the user's request from the official whisper.cpp model repository. Their upstream source is OpenAI Whisper, distributed under the MIT License. WhisperBridge pins revision `5359861c739e955e79d9a303bcbc70fb988958b1` and verifies each selected checkpoint against the file hash in `plugin/src/modelCatalog.ts`.

The native helper links `mlx-audio-swift` 0.1.3 at commit `d302a5c6080d2bb97bae38c7418f82abb76013b6`, distributed under the MIT License, plus the exact transitive Swift packages recorded in `WhisperBridge.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

The following model files download only after the user selects a profile and sends audio:

- Moonshine Tiny by Moonshine AI, MIT License.
- NVIDIA Parakeet TDT 0.6B v3, CC BY 4.0, using the pinned MLX 8-bit community conversion credited in the catalog.
- Cohere Labs Transcribe, Apache 2.0, using the user-approved pinned MLX 4-bit community conversion by beshkenadze.
- IBM Granite 4.0 Speech, Apache 2.0, using the pinned MLX 5-bit community conversion.

The repository records inactive MOSS and Canary-Qwen descriptors for adapter development. Those models are not offered for download because their native checkpoints have not passed release gates. See `docs/MODELS.md` for revisions and the current gate reasons.

WhisperBridge links [FluidAudio 0.15.5](https://github.com/FluidInference/FluidAudio/releases/tag/0.15.5), commit `19600a485baa4998812e4654b70d2bab8f2c9949`, under Apache License 2.0 for optional on-device speaker diarization. Diarization assets are separate downloads from FluidInference and carry CC BY 4.0 attribution.

WhisperBridge links [ZIPFoundation 0.9.20](https://github.com/weichsel/ZIPFoundation/releases/tag/0.9.20), commit `22787ffb59de99e5dc1fbfe80b19c97a904ad48d`, under the MIT License for bounded `.tst` archive handling.

The native subtitle, custom-export, overlap assignment, decoder-setting, compact-display, filler, project, and editing behavior described in [docs/STTTTS_REUSE.md](docs/STTTTS_REUSE.md) was independently ported from STTTTS commit `bbb51c5` with the repository owner's authorization. No STTTTS Python runtime or dependency is distributed.
