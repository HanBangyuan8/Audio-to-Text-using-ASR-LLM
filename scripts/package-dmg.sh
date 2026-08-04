#!/usr/bin/env bash
set -euo pipefail

PRODUCT_NAME="Audio to Text using ASR LLM"
EXECUTABLE_NAME="AudioToTextASRLLM"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
CONFIGURATION="${1:-release}"

cd "$ROOT_DIR"
PACKAGE_OUTPUT="$("$ROOT_DIR/scripts/package-app.sh" "$CONFIGURATION")"
APP_PATH="$(printf "%s\n" "$PACKAGE_OUTPUT" | tail -n 1)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
ARCHS="$(lipo -archs "$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME")"
if [[ "$ARCHS" == *"arm64"* && "$ARCHS" == *"x86_64"* ]]; then
    ARCH_LABEL="universal"
elif [[ "$ARCHS" == *"arm64"* ]]; then
    ARCH_LABEL="arm64"
else
    ARCH_LABEL="x86_64"
fi
ARTIFACT_BASENAME="Audio-to-Text-using-ASR-LLM-v${VERSION}-macOS-${ARCH_LABEL}"
ZIP_PATH="$DIST_DIR/${ARTIFACT_BASENAME}.zip"
DMG_PATH="$DIST_DIR/${ARTIFACT_BASENAME}.dmg"
STAGE_DIR="${TMPDIR:-/tmp}/audio-to-text-asr-llm-dmg.$$"
ZIP_APP_PATH="$STAGE_DIR/${ARTIFACT_BASENAME}.app"
DMG_ROOT="$STAGE_DIR/dmg"

clean_bundle_metadata() {
    local bundle_dir="$1"
    find "$bundle_dir" -name "._*" -delete
    if command -v dot_clean >/dev/null 2>&1; then
        dot_clean -m "$bundle_dir"
    fi
    if command -v xattr >/dev/null 2>&1; then
        xattr -cr "$bundle_dir" 2>/dev/null || true
    fi
}

trap 'rm -rf "$STAGE_DIR"' EXIT
rm -rf "$STAGE_DIR"
mkdir -p "$DMG_ROOT"

ditto --norsrc "$APP_PATH" "$ZIP_APP_PATH"
clean_bundle_metadata "$ZIP_APP_PATH"
if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$ZIP_APP_PATH" >/dev/null
    clean_bundle_metadata "$ZIP_APP_PATH"
    codesign --verify --deep --strict "$ZIP_APP_PATH"
fi

ditto --norsrc "$ZIP_APP_PATH" "$DMG_ROOT/$PRODUCT_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"
ditto -c -k --norsrc --keepParent "$ZIP_APP_PATH" "$ZIP_PATH"
hdiutil create -volname "$PRODUCT_NAME $VERSION" -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG_PATH" >/dev/null

printf '%s\n%s\n' "$ZIP_PATH" "$DMG_PATH"
