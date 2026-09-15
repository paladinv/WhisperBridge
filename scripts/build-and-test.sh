#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
ARTIFACT_ROOT="$PROJECT_ROOT/.build-artifacts"
RUN_ID="$(date '+%Y%m%d-%H%M%S')"
RUN_ROOT="$ARTIFACT_ROOT/runs/$RUN_ID"

mkdir -p \
  "$ARTIFACT_ROOT/logs" \
  "$ARTIFACT_ROOT/results" \
  "$ARTIFACT_ROOT/runtime-data" \
  "$RUN_ROOT/DerivedData" \
  "$RUN_ROOT/SourcePackages" \
  "$RUN_ROOT/module-cache" \
  "$RUN_ROOT/sdk-cache" \
  "$RUN_ROOT/tmp"

export TMPDIR="$RUN_ROOT/tmp/"
export CLANG_MODULE_CACHE_PATH="$RUN_ROOT/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$RUN_ROOT/module-cache"
export SDK_STAT_CACHE_DIR="$RUN_ROOT/sdk-cache"
export WHISPERBRIDGE_DATA_DIR="$ARTIFACT_ROOT/runtime-data"

COMMON_ARGS=(
  -project "$PROJECT_ROOT/WhisperBridge.xcodeproj"
  -scheme WhisperBridge
  -configuration Debug
  -destination "platform=macOS,arch=arm64"
  -derivedDataPath "$RUN_ROOT/DerivedData"
  -clonedSourcePackagesDirPath "$RUN_ROOT/SourcePackages"
  CODE_SIGNING_ALLOWED=NO
  COMPILER_INDEX_STORE_ENABLE=NO
)

xcodebuild "${COMMON_ARGS[@]}" \
  -resultBundlePath "$ARTIFACT_ROOT/results/build-$RUN_ID.xcresult" \
  build-for-testing > "$ARTIFACT_ROOT/logs/build-$RUN_ID.log" 2>&1

xcrun xcresulttool get build-results \
  --path "$ARTIFACT_ROOT/results/build-$RUN_ID.xcresult" \
  --compact > "$ARTIFACT_ROOT/results/build-$RUN_ID.json"

codesign --force --deep --sign - \
  "$RUN_ROOT/DerivedData/Build/Products/Debug/WhisperBridgeTests.xctest" \
  > "$ARTIFACT_ROOT/logs/codesign-$RUN_ID.log" 2>&1

xcodebuild test-without-building "${COMMON_ARGS[@]}" \
  -resultBundlePath "$ARTIFACT_ROOT/results/test-$RUN_ID.xcresult" \
  > "$ARTIFACT_ROOT/logs/test-$RUN_ID.log" 2>&1

xcrun xcresulttool get test-results tests \
  --path "$ARTIFACT_ROOT/results/test-$RUN_ID.xcresult" \
  --compact > "$ARTIFACT_ROOT/results/test-$RUN_ID.json"

print "Build and tests passed."
print "Logs: $ARTIFACT_ROOT/logs"
print "Results: $ARTIFACT_ROOT/results"
