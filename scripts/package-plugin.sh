#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
ARTIFACT_ROOT="$PROJECT_ROOT/.build-artifacts/plugin-package"
RUN_ID="$(date '+%Y%m%d-%H%M%S')"
DERIVED_DATA="$PROJECT_ROOT/.build-artifacts/plugin-derived-data"
SOURCE_PACKAGES="$PROJECT_ROOT/.build-artifacts/plugin-source-packages"
MODULE_CACHE="$PROJECT_ROOT/.build-artifacts/plugin-module-cache"
SDK_CACHE="$PROJECT_ROOT/.build-artifacts/plugin-sdk-cache"
LOCAL_TMP="$PROJECT_ROOT/.build-artifacts/plugin-tmp"
PLUGIN_NATIVE="$PROJECT_ROOT/plugin/native/macos-arm64"
RESULT_BUNDLE="$ARTIFACT_ROOT/WhisperBridgeCLI-build-$RUN_ID.xcresult"
RESULT_JSON="$ARTIFACT_ROOT/WhisperBridgeCLI-build-$RUN_ID.json"

mkdir -p "$ARTIFACT_ROOT" "$DERIVED_DATA" "$SOURCE_PACKAGES" "$MODULE_CACHE" "$SDK_CACHE" "$LOCAL_TMP" "$PLUGIN_NATIVE/Frameworks"

export TMPDIR="$LOCAL_TMP/"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE"
export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE"
export SDK_STAT_CACHE_DIR="$SDK_CACHE"

xcodebuild \
  -project "$PROJECT_ROOT/WhisperBridge.xcodeproj" \
  -scheme WhisperBridgeCLI \
  -configuration Release \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath "$DERIVED_DATA" \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES" \
  -resultBundlePath "$RESULT_BUNDLE" \
  CODE_SIGNING_ALLOWED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO \
  build > "$PROJECT_ROOT/.build-artifacts/plugin-build.log" 2>&1

xcrun xcresulttool get build-results \
  --path "$RESULT_BUNDLE" \
  --compact > "$RESULT_JSON"

rm -rf "$PLUGIN_NATIVE/Frameworks/whisper.framework"
mkdir -p "$PLUGIN_NATIVE/Frameworks/whisper.framework/Versions/A"
cp "$DERIVED_DATA/Build/Products/Release/WhisperBridgeCLI" "$PLUGIN_NATIVE/WhisperBridgeCLI"
cp "$PROJECT_ROOT/Vendor/whisper.framework/Versions/A/whisper" "$PLUGIN_NATIVE/Frameworks/whisper.framework/Versions/A/whisper"
install_name_tool \
  -change "@rpath/whisper.framework/Versions/Current/whisper" \
  "@rpath/whisper.framework/Versions/A/whisper" \
  "$PLUGIN_NATIVE/WhisperBridgeCLI"
chmod 755 "$PLUGIN_NATIVE/WhisperBridgeCLI"

cd "$PROJECT_ROOT/plugin"
npm run build > "$PROJECT_ROOT/.build-artifacts/plugin-typescript-build.log" 2>&1
npm test > "$PROJECT_ROOT/.build-artifacts/plugin-test.log" 2>&1

print "Plugin runtime packaged at $PLUGIN_NATIVE"
