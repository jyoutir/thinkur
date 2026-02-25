#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ──────────────────────────────────────────────────────────────
APP_NAME="thinkur"
SCHEME="thinkur"
BUNDLE_ID="com.jyo.thinkur"
TEAM_ID="YZ9FFMX8QS"
NOTARIZE_PROFILE="thinkur-notarize"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_DIR}/build"

# Read version from project.yml (safe read-only access to source tree)
VERSION=$(grep 'MARKETING_VERSION:' "${PROJECT_DIR}/project.yml" | head -1 | sed 's/.*"\(.*\)"/\1/')
BUILD_NUM=$(grep 'CURRENT_PROJECT_VERSION:' "${PROJECT_DIR}/project.yml" | head -1 | sed 's/.*"\(.*\)"/\1/')
DMG_NAME="${APP_NAME}-${VERSION}.dmg"

echo "=== Building ${APP_NAME} v${VERSION} (${BUILD_NUM}) ==="

# ─── Generate Xcode project (in source tree — writes .xcodeproj, safe) ────────
echo "→ Running xcodegen..."
cd "${PROJECT_DIR}"
xcodegen generate

# ─── Create isolated build environment ─────────────────────────────────────────
# Copy the project to /tmp so xcodebuild/codesign never touch the source tree.
# macOS Sequoia adds com.apple.macl and com.apple.provenance xattrs when
# xcodebuild reads files, which locks out Terminal, editors, git, etc.
# Building from /tmp avoids this entirely.
TEMP_DIR=$(mktemp -d /tmp/thinkur-release-XXXX)
echo "→ Copying project to isolated build dir: ${TEMP_DIR}"

rsync -a \
    --exclude '.git' \
    --exclude '.build' \
    --exclude 'build' \
    --exclude '.claude' \
    --exclude 'DerivedData' \
    --exclude 'docs' \
    --exclude 'Tests' \
    "${PROJECT_DIR}/" "${TEMP_DIR}/"

# Strip any existing xattrs from the copy (provenance from ~/Downloads)
xattr -cr "${TEMP_DIR}" 2>/dev/null || true

# All paths for the build now point to the temp copy
TEMP_BUILD_DIR="${TEMP_DIR}/build"
ARCHIVE_PATH="${TEMP_BUILD_DIR}/${APP_NAME}.xcarchive"
EXPORT_DIR="${TEMP_BUILD_DIR}/export"
APP_PATH="${EXPORT_DIR}/${APP_NAME}.app"
DMG_PATH="${TEMP_BUILD_DIR}/${DMG_NAME}"
DERIVED_DATA="${TEMP_DIR}/DerivedData"
EXPORT_OPTIONS="${TEMP_BUILD_DIR}/ExportOptions.plist"

# Always clean up the temp directory, even on failure
cleanup() {
    echo "→ Cleaning up temp directory..."
    rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

mkdir -p "${TEMP_BUILD_DIR}"

# ─── Create export options plist ────────────────────────────────────────────────
cat > "${EXPORT_OPTIONS}" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YZ9FFMX8QS</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
</dict>
</plist>
PLIST

# ─── Archive (from temp copy) ──────────────────────────────────────────────────
echo "→ Archiving (Release)..."
cd "${TEMP_DIR}"
xcodebuild archive \
    -scheme "${SCHEME}" \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    -derivedDataPath "${DERIVED_DATA}" \
    -destination "generic/platform=macOS" \
    DEVELOPMENT_TEAM="${TEAM_ID}" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="Developer ID Application" \
    OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime" \
    ARCHS=arm64 \
    -quiet

# ─── Export ─────────────────────────────────────────────────────────────────────
echo "→ Exporting archive..."
xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${EXPORT_DIR}" \
    -exportOptionsPlist "${EXPORT_OPTIONS}" \
    -quiet

# ─── Verify codesign ───────────────────────────────────────────────────────────
echo "→ Verifying code signature..."
codesign --verify --deep --strict "${APP_PATH}"
echo "  ✓ Code signature valid"

# ─── Create DMG ─────────────────────────────────────────────────────────────────
echo "→ Creating DMG..."
rm -f "${DMG_PATH}"

create-dmg \
    --volname "${APP_NAME}" \
    --volicon "${APP_PATH}/Contents/Resources/AppIcon.icns" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "${APP_NAME}.app" 150 190 \
    --app-drop-link 450 190 \
    --hide-extension "${APP_NAME}.app" \
    "${DMG_PATH}" \
    "${APP_PATH}" \
    || true  # create-dmg exits 2 on "image already exists" which is fine

if [ ! -f "${DMG_PATH}" ]; then
    echo "✗ DMG creation failed"
    exit 1
fi

# ─── Sign DMG ──────────────────────────────────────────────────────────────────
echo "→ Signing DMG..."
codesign --sign "Developer ID Application" \
    --timestamp \
    "${DMG_PATH}"
echo "  ✓ DMG signed"

# ─── Notarize ──────────────────────────────────────────────────────────────────
echo "→ Submitting for notarization (this may take 5-15 minutes)..."
xcrun notarytool submit "${DMG_PATH}" \
    --keychain-profile "${NOTARIZE_PROFILE}" \
    --wait

# ─── Staple ────────────────────────────────────────────────────────────────────
echo "→ Stapling notarization ticket..."
xcrun stapler staple "${DMG_PATH}"

# ─── Final verification ───────────────────────────────────────────────────────
echo "→ Final Gatekeeper check..."
spctl --assess --type open --context context:primary-signature -v "${DMG_PATH}"

# ─── Copy DMG back to source tree ─────────────────────────────────────────────
echo "→ Copying DMG to ${BUILD_DIR}..."
mkdir -p "${BUILD_DIR}"
cp "${DMG_PATH}" "${BUILD_DIR}/${DMG_NAME}"

# Temp directory is cleaned up by the EXIT trap

echo ""
echo "=== Done ==="
echo "DMG: ${BUILD_DIR}/${DMG_NAME}"
echo "Size: $(du -h "${BUILD_DIR}/${DMG_NAME}" | cut -f1)"
