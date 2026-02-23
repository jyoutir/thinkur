#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ──────────────────────────────────────────────────────────────
APP_NAME="thinkur"
GITHUB_REPO="jyoutir/thinkur-web"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_DIR}/build"

# Paths — customize if thinkur-web is elsewhere
THINKUR_WEB_DIR="${THINKUR_WEB_DIR:-${PROJECT_DIR}/../thinkur-web}"

# Read version from project.yml
VERSION=$(grep 'MARKETING_VERSION:' "${PROJECT_DIR}/project.yml" | head -1 | sed 's/.*"\(.*\)"/\1/')
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
TAG="v${VERSION}"

echo "=== Publishing ${APP_NAME} ${TAG} ==="

# ─── Validate ──────────────────────────────────────────────────────────────────
if [ ! -f "${DMG_PATH}" ]; then
    echo "✗ DMG not found: ${DMG_PATH}"
    echo "  Run ./scripts/build-dmg.sh first."
    exit 1
fi

if [ ! -d "${THINKUR_WEB_DIR}" ]; then
    echo "✗ thinkur-web repo not found at: ${THINKUR_WEB_DIR}"
    echo "  Set THINKUR_WEB_DIR or clone the repo alongside this one."
    exit 1
fi

# ─── Create GitHub Release ─────────────────────────────────────────────────────
echo "→ Creating GitHub Release ${TAG}..."
gh release create "${TAG}" \
    --repo "${GITHUB_REPO}" \
    --title "${APP_NAME} ${TAG}" \
    --notes "Release ${TAG}" \
    "${DMG_PATH}"

echo "  ✓ Release created with DMG attached"

# ─── Generate appcast.xml ──────────────────────────────────────────────────────
echo "→ Generating appcast.xml..."

# Find Sparkle's generate_appcast in DerivedData
GENERATE_APPCAST=$(find ~/Library/Developer/Xcode/DerivedData -name "generate_appcast" -type f 2>/dev/null | head -1)

if [ -z "${GENERATE_APPCAST}" ]; then
    echo "✗ generate_appcast not found in DerivedData."
    echo "  Build the project in Xcode first so Sparkle tools are available."
    exit 1
fi

# Create a staging directory with the DMG for appcast generation
APPCAST_STAGING="${BUILD_DIR}/appcast_staging"
rm -rf "${APPCAST_STAGING}"
mkdir -p "${APPCAST_STAGING}"
cp "${DMG_PATH}" "${APPCAST_STAGING}/"

# Generate appcast — this reads the DMG and creates/updates appcast.xml
# The download URL should point to the GitHub Release asset
"${GENERATE_APPCAST}" \
    --download-url-prefix "https://github.com/${GITHUB_REPO}/releases/download/${TAG}/" \
    "${APPCAST_STAGING}"

APPCAST_FILE="${APPCAST_STAGING}/appcast.xml"

if [ ! -f "${APPCAST_FILE}" ]; then
    echo "✗ appcast.xml was not generated"
    exit 1
fi

echo "  ✓ appcast.xml generated"

# ─── Update thinkur-web ────────────────────────────────────────────────────────
echo "→ Updating thinkur-web repo..."

# Copy appcast.xml into the web repo's public directory
# Vite copies public/ files as-is to dist/
mkdir -p "${THINKUR_WEB_DIR}/public"
cp "${APPCAST_FILE}" "${THINKUR_WEB_DIR}/public/appcast.xml"

# Commit and push
cd "${THINKUR_WEB_DIR}"
git add public/appcast.xml
git commit -m "Update appcast.xml for ${TAG}" || echo "  (no changes to commit)"
git push

echo "  ✓ appcast.xml pushed to thinkur-web"

echo ""
echo "=== Done ==="
echo "Release: https://github.com/${GITHUB_REPO}/releases/tag/${TAG}"
echo "Appcast: https://thinkur.app/appcast.xml (after Pages deploy)"
