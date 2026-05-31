#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="Audio to Text using ASR LLM"
PRODUCT_NAME="AudioToTextASRLLM"
BUNDLE_ID="dev.han.AudioToTextASRLLM"
VERSION="1.0.0"
CONFIGURATION="${1:-release}"
DIST_DIR="$ROOT_DIR/dist"
FINAL_APP_DIR="$DIST_DIR/$APP_NAME.app"
FINAL_ZIP_PATH="$DIST_DIR/Audio.to.Text.using.ASR.LLM-v${VERSION}-macOS.zip"
LEGACY_ZIP_PATH="$DIST_DIR/$APP_NAME.zip"
STAGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/audio-to-text-asr-llm.XXXXXX")"
APP_DIR="$STAGE_DIR/$APP_NAME.app"
VERIFY_DIR="$STAGE_DIR/verify"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cleanup() {
  rm -rf "$STAGE_DIR"
}
trap cleanup EXIT

clean_bundle_metadata() {
  local bundle_dir="$1"
  find "$bundle_dir" -name "._*" -delete
  if command -v dot_clean >/dev/null 2>&1; then
    dot_clean -m "$bundle_dir"
  fi
  if command -v xattr >/dev/null 2>&1; then
    xattr -cr "$bundle_dir" 2>/dev/null || true
    while IFS= read -r -d '' file_path; do
      xattr -d com.apple.FinderInfo "$file_path" 2>/dev/null || true
      xattr -d 'com.apple.fileprovider.fpfs#P' "$file_path" 2>/dev/null || true
    done < <(find "$bundle_dir" -print0)
  fi
}

mkdir -p "$DIST_DIR"
rm -rf "$APP_DIR" "$FINAL_APP_DIR" "$FINAL_ZIP_PATH" "$LEGACY_ZIP_PATH"

swift build -c "$CONFIGURATION"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "Support/Info.plist" "$CONTENTS_DIR/Info.plist"
cp ".build/$CONFIGURATION/$PRODUCT_NAME" "$MACOS_DIR/$PRODUCT_NAME"
chmod +x "$MACOS_DIR/$PRODUCT_NAME"
if [[ -f "Resources/AppIcon.svg" ]]; then
  cp "Resources/AppIcon.svg" "$RESOURCES_DIR/AppIcon.svg"
fi

clean_bundle_metadata "$APP_DIR"
codesign --force --deep --sign - "$APP_DIR"
clean_bundle_metadata "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

ditto -c -k --norsrc --keepParent "$APP_DIR" "$FINAL_ZIP_PATH"
mkdir -p "$VERIFY_DIR"
ditto -x -k "$FINAL_ZIP_PATH" "$VERIFY_DIR"
codesign --verify --deep --strict --verbose=2 "$VERIFY_DIR/$APP_NAME.app"

ditto --norsrc "$APP_DIR" "$FINAL_APP_DIR"
clean_bundle_metadata "$FINAL_APP_DIR"
codesign --verify --deep "$FINAL_APP_DIR"
cp "$FINAL_ZIP_PATH" "$LEGACY_ZIP_PATH"

echo "Packaged:"
ls -lh "$FINAL_APP_DIR" "$FINAL_ZIP_PATH" "$LEGACY_ZIP_PATH"
