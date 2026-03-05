#!/usr/bin/env bash
set -euo pipefail

# ─── build-dmg.sh ────────────────────────────────────────────────────────────
# Archives, signs, notarizes, and creates a DMG for release.
# Builds in /tmp to avoid macOS provenance xattr issues.

source "$(dirname "$0")/lib/release-common.sh"

VERSION="$(read_version)"
BUILD_NUM="$(read_build_number)"
DMG_FILE="$(dmg_name)"
SCHEME="thinkur"
ENTITLEMENTS_PATH="Sources/thinkur/Resources/thinkur.entitlements"

echo "=== Building ${APP_NAME} v${VERSION} (${BUILD_NUM}) ==="

# ─── Generate Xcode project (in source tree — writes .xcodeproj, safe) ────────
log_step "Running xcodegen..."
cd "${PROJECT_DIR}"
xcodegen generate

# ─── Create isolated build environment ─────────────────────────────────────────
# Copy the project to /tmp so xcodebuild/codesign never touch the source tree.
# macOS Sequoia adds com.apple.macl and com.apple.provenance xattrs when
# xcodebuild reads files, which locks out Terminal, editors, git, etc.
TEMP_DIR=$(mktemp -d /tmp/thinkur-release-XXXX)
log_step "Copying project to isolated build dir: ${TEMP_DIR}"

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
DMG_PATH="${TEMP_BUILD_DIR}/${DMG_FILE}"
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
cat > "${EXPORT_OPTIONS}" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
</dict>
</plist>
PLIST

# ─── Archive (from temp copy) ──────────────────────────────────────────────────
log_step "Archiving (Release)..."
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
# Try exportArchive first; if it fails (Xcode 26 broke developer-id method),
# fall back to extracting the already-signed app directly from the archive.
log_step "Exporting archive..."
mkdir -p "${EXPORT_DIR}"

if ! xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${EXPORT_DIR}" \
    -exportOptionsPlist "${EXPORT_OPTIONS}" \
    -quiet 2>/dev/null; then
    echo "  exportArchive failed — extracting and re-signing manually"
    cp -R "${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app" "${APP_PATH}"

    # Deep-sign all binaries with Developer ID + timestamp + hardened runtime.
    # exportArchive normally does this; we must replicate it for notarization.
    log_step "Re-signing app bundle (deep)..."
    codesign --deep --force --options runtime --timestamp \
        --sign "Developer ID Application" \
        --entitlements "${TEMP_DIR}/${ENTITLEMENTS_PATH}" \
        "${APP_PATH}"
fi

# ─── Verify codesign ───────────────────────────────────────────────────────────
log_step "Verifying code signature..."
codesign --verify --deep --strict "${APP_PATH}"
log_pass "Code signature valid"

# ─── Create DMG ─────────────────────────────────────────────────────────────────
log_step "Creating DMG..."
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
    log_fail "DMG creation failed"
    exit 1
fi

# ─── Sign DMG ──────────────────────────────────────────────────────────────────
log_step "Signing DMG..."
codesign --sign "Developer ID Application" \
    --timestamp \
    "${DMG_PATH}"
log_pass "DMG signed"

# ─── Notarize ──────────────────────────────────────────────────────────────────
log_step "Submitting for notarization (this may take 5-15 minutes)..."
xcrun notarytool submit "${DMG_PATH}" \
    --keychain-profile "${NOTARIZE_PROFILE}" \
    --wait

# ─── Staple ────────────────────────────────────────────────────────────────────
log_step "Stapling notarization ticket..."
xcrun stapler staple "${DMG_PATH}"

# ─── Final verification ───────────────────────────────────────────────────────
log_step "Final Gatekeeper check..."
spctl --assess --type open --context context:primary-signature -v "${DMG_PATH}"

# ─── Copy DMG back to source tree ─────────────────────────────────────────────
log_step "Copying DMG to ${BUILD_DIR}..."
mkdir -p "${BUILD_DIR}"
cp "${DMG_PATH}" "${BUILD_DIR}/${DMG_FILE}"

# Temp directory is cleaned up by the EXIT trap

echo ""
echo "=== Done ==="
echo "DMG: ${BUILD_DIR}/${DMG_FILE}"
echo "Size: $(du -h "${BUILD_DIR}/${DMG_FILE}" | cut -f1)"
