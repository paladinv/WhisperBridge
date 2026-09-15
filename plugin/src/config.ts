import { createConfigSchematics } from "@lmstudio/sdk";
import { AVAILABLE_MODELS, DEFAULT_MODEL_ID, LANGUAGE_OPTIONS } from "./modelCatalog";

export const configSchematics = createConfigSchematics()
  .field(
    "model",
    "select",
    {
      displayName: "Speech model",
      subtitle: "The selected model downloads on the first audio message, then stays on this Mac.",
      options: AVAILABLE_MODELS.map(model => ({ value: model.id, displayName: model.displayName }))
    },
    DEFAULT_MODEL_ID
  )
  .field(
    "language",
    "select",
    {
      displayName: "Spoken language",
      subtitle: "Automatic detection works for most recordings.",
      options: LANGUAGE_OPTIONS
    },
    "auto"
  )
  .field(
    "includeFilename",
    "boolean",
    {
      displayName: "Include source filename",
      subtitle: "Add the recording name above the transcript."
    },
    true
  )
  .build();
