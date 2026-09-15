# Plugin development

Requirements: LM Studio 0.4.19 or newer with plugin beta access, Xcode 16 or newer, Node.js for repository tests, and an Apple silicon Mac.

1. Generate the Xcode project after changing `project.yml`:

   ```sh
   xcodegen generate
   ```

2. Install plugin dependencies:

   ```sh
   cd plugin
   npm install
   ```

3. Build and stage the native helper entirely inside the repository:

   ```sh
   ./scripts/package-plugin.sh
   ```

4. Start LM Studio, then run the development plugin from the `plugin` directory:

   ```sh
   WHISPERBRIDGE_DATA_DIR="$PWD/../.build-artifacts/plugin-data" lms dev
   ```

5. With LM Studio's service running and the licensed smoke fixture present, exercise its real file-handle backend without UI automation:

   ```sh
   npm run test:integration:lmstudio
   ```

   This uploads the fixture through `client.files.prepareFile()`, resolves the managed path, performs local transcription, checks prompt replacement and attachment consumption, and disconnects so LM Studio removes its temporary upload. It does not replace composer, history, or plugin-ordering QA.

Use `lms dev --install` for a persistent local installation. The development data override keeps the model and partial downloads under `.build-artifacts/`. End-user installations use `~/Library/Application Support/LM Studio/WhisperBridge`.

Installed prompt preprocessors are enabled per chat from the chat sidebar's **Integrations** panel. They are not listed in **Settings → Integrations → Tool Call Confirmation**, which applies only to tools a model can call.

LM Studio 0.4.23 and 0.4.24 do not expose registered plugin configuration fields because of host bug #2365. Exercise the fallback with an attached audio file and a first line such as `/wb model=better language=auto filename=on`. The plugin strips the line, records the resolved choice in the transformed chat message, and saves `/wb default ...` changes under the selected `WHISPERBRIDGE_DATA_DIR`. Do not use text-only `/wb` messages as configuration commands.

The first attached audio prompt downloads and verifies the resolved model. Selection itself performs no network activity. Text-only prompts return immediately without reading configuration or history, touching the filesystem, starting the helper, or checking the model.

Production models live under `~/Library/Application Support/LM Studio/WhisperBridge/models/<model-id>/<revision>/`. Development and model-smoke commands must set `WHISPERBRIDGE_DATA_DIR` to a path under `.build-artifacts/`; the helper also redirects Hugging Face, Transformers, and MLX caches below that model revision so those runtimes cannot silently create global model caches.
