# Plugin implementation evidence — 2026-09-14

Environment: Apple M4 Max MacBook Pro, macOS 26.4.1, Xcode 26.4.1 (17E202), LM Studio 0.4.19+2, `@lmstudio/sdk` 1.4.0, Whisper Base Multilingual SHA-256 `60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe`.

## Automated plugin checks

`npm run build` completed with no TypeScript errors. The final `npm test` run is recorded in `.build-artifacts/plugin-test.log` and includes all current selectors with no failures, skips, or cancellations.

The 16 checks cover audio extension and size policy, prompt formatting, filename sanitization, explicit model storage, versioned helper communication, the zero-work text-only path and microbenchmark, idempotence, successful message replacement, preservation after runtime or context-overflow failure, rejection of multiple audio inputs before model work, and prompt cancellation.

## Native helper and real speech

`scripts/package-plugin.sh` built the Apple silicon helper with code signing disabled and all Derived Data, package caches, module caches, result bundles, JSON, temporary files, and logs under `.build-artifacts/`. The package contains the helper and `whisper.framework` under `plugin/native/macos-arm64/`.

The helper processed `.build-artifacts/fixtures/whisper-smoke-real.wav` using the pinned Base model. Cold observed wall time was approximately 8.0 seconds, including a 7.6-second first Metal-library initialization. A warm run completed in approximately 0.61 seconds. Both were below the existing 15-second short-fixture budget. The exact transcript was:

> Whisper Bridge turns audio into text for local models.

The final minimized package was also exercised successfully; its structured output is retained in `.build-artifacts/helper-smoke-response-packaged.json`. Progress values remained within 0 through 1 after the clamp fix.

## Existing application regression

The regenerated application and test bundle completed `build-for-testing`. Xcode's `test-without-building` service failed to create the valid bundle on this host. The already-built bundle was therefore run directly with `xcrun xctest`. It executed 11 selectors: 11 passed, 0 failed, 0 skipped, and 0 unexpected in 0.437 seconds. This included six domain tests, two decoder tests, one real Whisper smoke test, and two serial performance tests. The full output is retained in `.build-artifacts/logs/xctest-20260914-174848.log`.

## LM Studio installation and deployed-helper verification

The daemon could not read the source directly from the macOS Documents folder, so an identical temporary source was placed under LM Studio's own `working-directories` area. The official installer then completed:

```text
Installing the plugin paladinv/whisperbridge...
Successfully installed paladinv/whisperbridge.
```

LM Studio wrote `install-state.json` with installer `node-plugin-installer-v1`. Its server log recorded the installed `paladinv/whisperbridge` client connecting, printing its registration message, and registering `setPromptPreprocessor`. The deployed helper and explicit `@rpath/whisper.framework/Versions/A/whisper` dependency were present and executable under the installed plugin directory.

The pinned model was copied to the configured LM Studio application-support cache and rechecked at SHA-256 `60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe`. The helper was then invoked from the installed plugin directory against `.build-artifacts/fixtures/whisper-smoke-real.wav`. It returned bounded decoding/transcription progress and the exact expected transcript. Structured output and diagnostics are retained in `.build-artifacts/installed-helper-smoke-response.json` and `.build-artifacts/logs/installed-helper-smoke.stderr.log`.

The repeatable `npm run test:integration:lmstudio` check connected through SDK 1.4.0 without UI automation. LM Studio's server log records `uploadFileBase64` receiving `whisper-smoke-real.wav` and returning a 103,362-byte managed file identifier. The test resolved that genuine `FileHandle` with `getFilePath()`, verified the managed file, ran the real model and helper, checked the expected transcript marker and text, confirmed that the processed attachment was consumed, and observed the final done status. It passed in 1.27 seconds on a warm runtime. Output is retained in `.build-artifacts/lmstudio-headless-integration.stdout.log`; helper diagnostics are in `.build-artifacts/logs/lmstudio-headless-integration.stderr.log`. Context-size validation is covered separately by the unit suite because a headless file client has no composer-selected model context.

QA-054 remains BLOCKED because its full pass condition also requires choosing audio through LM Studio's actual attachment UI, observing the registered host hook's prompt transformation, and installing without a terminal. History persistence, multi-chat behavior, plugin ordering, accessibility, signing, Hub distribution, and novice installation remain NOT_RUN. Successful installation, registration, supported file-handle processing, and deployed-helper inference are recorded as partial evidence rather than a full native-product pass.
