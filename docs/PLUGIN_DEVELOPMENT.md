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

The first attached audio prompt downloads and verifies Whisper Base Multilingual. Text-only prompts return immediately without reading configuration, touching the filesystem, starting the helper, or checking the model.
