# Initial repository validation

Date: 2026-09-13. Scope: specification, QA kit and logo only.

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

Validation logs and synthetic probes are stored in the ignored `.build-artifacts/validation/` directory. Negative fixtures and their hashes are in `.build-artifacts/fixtures/`. Recreate fixtures with `python3 scripts/make_negative_fixtures.py`. These fixtures contain no recorded human speech.

**Product QA: 0 passed, 63 NOT_RUN** (55 baseline, 7 conditional native, 1 future). No app exists yet. Recognition accuracy, LM Studio integration, installer behavior, actual resource use, privacy traffic and accessibility have not been tested. The full matrix and novice study remain required. No compilation or Xcode build was needed for this documentation deliverable.

The release checker validates ledger completeness and evidence paths, not the truth or adequacy of evidence. A human QA reviewer must assess actual results before release.
