# Repository validation status

Updated: 2026-09-14. Scope: source implementation, automated checks, specification, QA kit, and brand assets.

| Check actually performed | Result |
| --- | --- |
| QA definition and record validation | PASS: 63 cases cover all 20 use cases and 12 requirements. |
| Baseline release gate with initial results | Expected exit 2: blocked; 55 baseline cases have not passed. |
| Native release gate with initial results | Expected exit 2: blocked; baseline plus 7 native cases have not passed. |
| Synthetic PASS result without evidence | Expected exit 1: rejected. Actual product ledger left unchanged. |
| Negative fixture generation | Four files generated; silence/noise WAV headers and 10-second duration verified. |
| SVG parsing | Three vector assets parse successfully. |
| Primary logo visual review | Rendered via Quick Look and inspected: full wordmark, waveform/text motif and tagline visible without overlap. |
| Local Markdown links | All resolve to existing files. |
| Unsigned macOS test build | PASS: SwiftUI app and unhosted XCTest bundle compile with all generated paths under `.build-artifacts/`. |
| Automated XCTest suite | PASS: 11 tests, including PCM conversion, invalid input, model integrity, real `whisper.cpp` transcription, and performance budgets for a local synthesized speech fixture. |
| Application launch smoke check | PASS: the unsigned Debug application launched and remained responsive at process level until intentionally terminated. |

Validation logs and synthetic probes are stored in the ignored `.build-artifacts/validation/` directory. Negative fixtures and their hashes are in `.build-artifacts/fixtures/`. Recreate fixtures with `python3 scripts/make_negative_fixtures.py`. These fixtures contain no recorded human speech.

**Product QA: 0 passed, 63 NOT_RUN** (55 baseline, 7 conditional native, 1 future). A source implementation and unsigned Debug build now exist, but recognition accuracy on the licensed corpus, LM Studio interoperability, signed installer behavior, resource limits, privacy traffic, accessibility, and novice setup have not been tested. The full matrix and novice study remain required. Automated XCTest success does not change the manual product ledger.

The release checker validates ledger completeness and evidence paths, not the truth or adequacy of evidence. A human QA reviewer must assess actual results before release.

See [the implementation regression report](REGRESSION_REPORT.md) for selector accounting, command durations, build reuse, and measured local performance.
