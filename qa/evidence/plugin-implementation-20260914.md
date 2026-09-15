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

## LM Studio installation gate

The running LM Studio instance accepted the installation request far enough to identify `paladinv/whisperbridge`, then returned:

```text
Installing the plugin paladinv/whisperbridge...
Error: EPERM: operation not permitted, open '/Users/oba/Documents/Tech/Coding Projects/LM-Studio Whisper Add/plugin/manifest.json'
```

The LM Studio daemon lacks macOS Documents-folder permission on this host. QA-054 is BLOCKED because an installed in-app run has not occurred. Attachment transformation, history persistence, multi-chat behavior, plugin ordering, accessibility, signing, Hub distribution, and novice installation remain NOT_RUN. Automated source and helper success do not mark those product cases as passed.
