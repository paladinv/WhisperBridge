# Suggestions and delivery order

| Order | Improvement | User benefit | Tradeoff / proof needed |
| --- | --- | --- | --- |
| 1 | Ship a signed, single-window app with one recommended model | Removes most setup friction | Test clean-machine installation with five casual users. |
| 2 | Add source playback and click-to-seek timestamps | Makes correcting names and numbers easier | Accurate alignment and keyboard-accessible playback; add audio-device QA. |
| 3 | Offer “Faster” and “More accurate” after benchmarking | Adapts to slower computers without exposing model jargon | Show measured download/storage needs and benchmark both presets. |
| 4 | Prove a supported LM Studio integration | Removes manual paste if the host supports it | Native API and distribution spike; keep copy available on incompatibility. |
| 5 | Optional prompt recipes: summarize, action items, draft email | Saves repetitive typing | Preserve raw transcript; preview exactly what will be sent; measure factual fidelity. |
| 6 | Small ordered batch queue | Helps users with several recordings | Cancel/retry individual jobs; keep filenames and transcript ownership distinct. |
| 7 | Explicitly enabled local transcript history | Helps recover prior work | Retention and delete controls; explain that exports and chat history are separate. |
| 8 | Windows/Intel builds, then Linux if demand supports it | Wider reach | Platform decoder, installer, acceleration and accessibility QA per OS. |

Do not start with RAG, embeddings, live voice conversation, cloud transcription, automatic clipboard reading or speaker attribution. They expand setup and correctness obligations without improving the core saved-audio workflow.

Milestone A: native integration feasibility and packaging spike. Milestone B: companion import/decode/transcribe/review/copy vertical slice. Milestone C: real audio corpus and failure recovery, accessibility and novice studies. Milestone D: release candidate with signed packaging and independent QA. Native integration can follow after its own evidence gate; never imply it is already implemented.
