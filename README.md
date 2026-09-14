# WhisperBridge

**Audio files → reviewed text → LM Studio prompts.**

![WhisperBridge logo](assets/logo.svg)

WhisperBridge is a proposed simple, local transcription companion for LM Studio. This initial repository delivers the product definition, use cases, executable QA bookkeeping, release acceptance tests and original vector identity. **It does not yet contain a working transcription app or an installable LM Studio plugin.**

## Start here

- [Product specification and integration decision](docs/PRODUCT.md)
- [Complete use cases](docs/USE_CASES.md)
- [Hands-on QA strategy and release gates](qa/PLAN.md)
- [Step-by-step test cases](qa/CASES.md)
- [Machine-readable test cases](qa/cases.json)
- [Test execution records](qa/results.json)
- [Research and reference comparison](docs/RESEARCH.md)
- [Prioritized improvements](docs/ROADMAP.md)
- [Logo assets and usage](assets/BRAND.md)

## Proposed everyday workflow

1. Open the packaged app; download its recommended speech model once.
2. Choose or drop an audio file and select **Transcribe**.
3. Read and edit the transcript, then choose **Copy transcript**.
4. Paste into the LM Studio prompt, add a question, and send when ready.

The first release requires no Python, terminal, API key, database, or LM Studio server setup for this workflow. These are design requirements, not a claim that an installer exists. Native in-app insertion is a separately gated integration goal; copying and pasting is the explicit baseline, not equivalent to an embedded add-on.

## Validate this QA kit

Run from the repository root using Python 3.9 or newer:

```sh
python3 scripts/check_qa.py
python3 scripts/check_qa.py --release
```

The first command checks coverage and record consistency. The second intentionally fails until all baseline product tests have passed with evidence. Neither command transcribes audio or proves the app works. See [the initial validation report](qa/INITIAL_REPORT.md).

The working name and logo are original project concepts, not an official LM Studio or OpenAI identity. No upstream code was copied. Distribution licensing and name availability must be decided before release.
