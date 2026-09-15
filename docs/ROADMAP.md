# Suggestions and delivery order

| Order | Improvement | User benefit | Tradeoff / proof needed |
| --- | --- | --- | --- |
| 1 | Prove the LM Studio plugin file and runtime contracts | Enables in-app transcription without relying on undocumented behavior | Pass Gates A and B in the [plugin plan](LM_STUDIO_PLUGIN_PLAN.md). |
| 2 | Ship the prompt-preprocessor vertical slice with one recommended model | Removes the separate-app and clipboard workflow | Validate exact prompt transformation, chat isolation, progress, cancellation, and clean installation. |
| 3 | Offer “Faster” and “More accurate” after benchmarking | Adapts to slower computers without exposing model jargon | Show measured download/storage needs and benchmark both presets. |
| 4 | Add a supported review-before-send experience if LM Studio exposes a composer hook | Lets users correct names and numbers before inference | Do not claim this with the current after-Send preprocessor API. |
| 5 | Optional prompt recipes: summarize, action items, draft email | Saves repetitive typing | Preserve raw transcript; preview exactly what will be sent; measure factual fidelity. |
| 6 | Small ordered batch queue | Helps users with several recordings | Cancel/retry individual jobs; keep filenames and transcript ownership distinct. |
| 7 | Explicitly enabled local transcript history | Helps recover prior work | Retention and delete controls; explain that exports and chat history are separate. |
| 8 | Windows/Intel builds, then Linux if demand supports it | Wider reach | Platform decoder, installer, acceleration and accessibility QA per OS. |

Do not start with RAG, embeddings, live voice conversation, cloud transcription, automatic clipboard reading or speaker attribution. They expand setup and correctness obligations without improving the core saved-audio workflow.

Milestone A: plugin attachment and runtime feasibility spikes. Milestone B: in-app prompt-preprocessor vertical slice. Milestone C: casual installation, real audio corpus, failure recovery, accessibility, performance, and novice studies. Milestone D: release candidate with supported Hub packaging and independent QA. The current companion remains a fallback until the plugin passes its evidence gates; never imply native integration is already implemented.
