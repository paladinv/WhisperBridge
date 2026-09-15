import { createConfigSchematics } from "@lmstudio/sdk";

export const configSchematics = createConfigSchematics()
  .field(
    "language",
    "select",
    {
      displayName: "Transcription language",
      subtitle: "Automatic detection works for most recordings.",
      options: [
        { value: "auto", displayName: "Detect automatically" },
        { value: "en", displayName: "English" },
        { value: "fr", displayName: "French" },
        { value: "es", displayName: "Spanish" },
        { value: "de", displayName: "German" },
        { value: "it", displayName: "Italian" },
        { value: "pt", displayName: "Portuguese" },
        { value: "ja", displayName: "Japanese" },
        { value: "zh", displayName: "Chinese" },
        { value: "ko", displayName: "Korean" }
      ]
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
