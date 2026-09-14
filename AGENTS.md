# Workspace rules

Keep all generated outputs, temporary files, caches, models, test evidence and build logs inside this repository. Do not use host temporary folders or `/dev/null` in commands. Read installed tools as needed, but do not place task outputs outside this workspace.

For future Xcode work, explicitly set derivedDataPath, clonedSourcePackagesDirPath, resultBundlePath and logs under `.build-artifacts/`; set CODE_SIGNING_ALLOWED=NO for local unsigned builds. Set TMPDIR and compiler caches to workspace directories where supported. Inspect tools for additional implicit output locations before running them. Never assume setting derivedDataPath alone contains every write.

This repository currently contains a product specification and QA kit, not an implemented app. Never report planned or blocked product tests as passing. Update evidence when real binaries and licensed fixtures are available.

Use repository-local Git identity: codingmonkey <paladin@vifmail.com>. Do not change global Git settings. Do not publish a remote repository without a request.
