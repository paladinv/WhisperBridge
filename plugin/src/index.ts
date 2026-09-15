import type { PluginContext } from "@lmstudio/sdk";
import { configSchematics } from "./config";
import { preprocess } from "./preprocess";

export async function main(context: PluginContext): Promise<void> {
  context.withConfigSchematics(configSchematics);
  context.withPromptPreprocessor(preprocess);
}
