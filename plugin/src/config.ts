import { createConfigSchematics } from "@lmstudio/sdk";
import { AVAILABLE_MODELS, LANGUAGE_OPTIONS } from "./modelCatalog";
import { INHERIT_SETTING } from "./settings";

export const configSchematics = createConfigSchematics()
  .field(
    "model",
    "select",
    {
      displayName: "Speech model",
      subtitle: "The selected model downloads on the first audio message, then stays on this Mac.",
      options: [
        { value: INHERIT_SETTING, displayName: "Use WhisperBridge default" },
        ...AVAILABLE_MODELS.map(model => ({ value: model.id, displayName: model.displayName }))
      ]
    },
    INHERIT_SETTING
  )
  .field(
    "language",
    "select",
    {
      displayName: "Spoken language",
      subtitle: "Automatic detection works for most recordings.",
      options: [
        { value: INHERIT_SETTING, displayName: "Use WhisperBridge default" },
        ...LANGUAGE_OPTIONS
      ]
    },
    INHERIT_SETTING
  )
  .field(
    "filename",
    "select",
    {
      displayName: "Include source filename",
      subtitle: "Add the recording name above the transcript.",
      options: [
        { value: INHERIT_SETTING, displayName: "Use WhisperBridge default" },
        { value: "include", displayName: "Include filename" },
        { value: "omit", displayName: "Omit filename" }
      ]
    },
    INHERIT_SETTING
  )
  .build();
