import type { ChatMessage, PromptPreprocessorController } from "@lmstudio/sdk";
import { configSchematics } from "./config";
import { TRANSCRIPT_MARKER } from "./constants";
import { runHelper, type HelperProgress } from "./helper";
import { ensureModel } from "./modelStore";
import { modelByID, supportsLanguage } from "./modelCatalog";
import { formatPrompt, isSupportedAudio, validateAudio } from "./prompt";
import {
  latestHistorySettings,
  loadGlobalSettings,
  parseDirective,
  resolveSettings,
  saveGlobalSettings
} from "./settings";

export interface PreprocessDependencies {
  ensureModel: typeof ensureModel;
  runHelper: typeof runHelper;
  validateContext: typeof validateContext;
  loadGlobalSettings: typeof loadGlobalSettings;
  saveGlobalSettings: typeof saveGlobalSettings;
}

async function validateContext(
  ctl: PromptPreprocessorController,
  prompt: string,
  existingHistory?: Awaited<ReturnType<PromptPreprocessorController["pullHistory"]>>
): Promise<void> {
  const model = await ctl.client.llm.model();
  const history = existingHistory ?? await ctl.pullHistory();
  history.append("user", prompt);
  const formatted = await model.applyPromptTemplate(history);
  const tokenCount = await model.countTokens(formatted);
  const contextLength = await model.getContextLength();
  if (tokenCount > contextLength) {
    throw new Error(
      `The transcript does not fit this model's ${contextLength.toLocaleString()}-token context. ` +
      "Use a model with a larger context or transcribe a shorter recording."
    );
  }
}

const defaultDependencies: PreprocessDependencies = {
  ensureModel,
  runHelper,
  validateContext,
  loadGlobalSettings,
  saveGlobalSettings
};

function statusText(progress: HelperProgress): string {
  const percent = progress.fraction === undefined ? "" : ` (${Math.round(progress.fraction * 100)}%)`;
  switch (progress.stage) {
    case "validating": return "Checking audio…";
    case "decoding": return `Preparing audio…${percent}`;
    case "transcribing": return `Transcribing locally…${percent}`;
  }
}

export function createPreprocessor(dependencies: PreprocessDependencies = defaultDependencies) {
  return async function preprocess(
    ctl: PromptPreprocessorController,
    userMessage: ChatMessage
  ): Promise<ChatMessage> {
    const originalText = userMessage.getText();
    if (originalText.includes(TRANSCRIPT_MARKER)) return userMessage;

    const audioFiles = userMessage.getFiles(ctl.client).filter(isSupportedAudio);
    if (audioFiles.length === 0) return userMessage;
    if (audioFiles.length > 1) {
      throw new Error("Attach one audio file per prompt so each transcript stays clearly identified.");
    }

    const audioFile = audioFiles[0];
    validateAudio(audioFile);
    const directive = parseDirective(originalText);
    const instruction = directive?.instruction ?? originalText;
    const config = ctl.getPluginConfig(configSchematics);
    const history = await ctl.pullHistory();
    const globalSettings = directive?.kind === "resetGlobal"
      ? { version: 1 as const }
      : await dependencies.loadGlobalSettings();
    const settings = resolveSettings({
      directive,
      history: latestHistorySettings(history
        .getMessagesArray()
        .filter(message => message.getRole() === "user")
        .map(message => message.getText())),
      ui: {
        model: config.get("model"),
        language: config.get("language"),
        filename: config.get("filename")
      },
      global: globalSettings
    });
    const selectedModel = modelByID(settings.modelID);
    if (!selectedModel || !selectedModel.available) {
      throw new Error(selectedModel?.unavailableReason ?? "The selected speech model is unavailable.");
    }
    const configuredLanguage = settings.language;
    if (!supportsLanguage(selectedModel, configuredLanguage)) {
      throw new Error(
        `${selectedModel.displayName.split(" · ")[0]} does not support the selected language. ` +
        "Choose Detect automatically or a compatible speech model."
      );
    }
    const helperLanguage = configuredLanguage === "auto" && !selectedModel.automaticLanguageDetection
      ? selectedModel.languages[0]
      : configuredLanguage;
    const status = ctl.createStatus({ status: "loading", text: "Preparing WhisperBridge…" });

    try {
      const modelDirectory = await dependencies.ensureModel(selectedModel, ctl.abortSignal, fraction => {
        status.setState({
          status: "loading",
          text: `Downloading ${selectedModel.displayName.split(" · ")[0]}… ${Math.round(fraction * 100)}%`
        });
      });
      const audioPath = await audioFile.getFilePath();
      const result = await dependencies.runHelper(
        audioPath,
        selectedModel,
        modelDirectory,
        helperLanguage,
        ctl.abortSignal,
        progress => status.setState({ status: "loading", text: statusText(progress) })
      );

      const transformed = formatPrompt(
        instruction,
        result.text,
        audioFile.name,
        settings
      );
      await dependencies.validateContext(ctl, transformed, history);
      if (directive?.kind === "global") await dependencies.saveGlobalSettings(directive.update);
      if (directive?.kind === "resetGlobal") await dependencies.saveGlobalSettings(null);
      userMessage.consumeFiles(ctl.client, file => file.identifier === audioFile.identifier);
      userMessage.replaceText(transformed);
      status.setState({ status: "done", text: "Audio transcribed locally" });
      return userMessage;
    } catch (error) {
      if (ctl.abortSignal.aborted) {
        status.setState({ status: "canceled", text: "Transcription canceled" });
        throw new Error("Transcription was cancelled.");
      }
      status.setState({ status: "canceled", text: "WhisperBridge needs attention" });
      throw error;
    }
  };
}

export const preprocess = createPreprocessor();
