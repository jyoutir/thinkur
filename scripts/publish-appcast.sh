#!/usr/bin/env bash
set -euo pipefail

# ─── publish-appcast.sh ─────────────────────────────────────────────────────
# Generates appcast.xml, pushes to thinkur-web, and publishes the draft release.
# This is the ONLY step that makes a release visible to Sparkle users.

source "$(dirname "$0")/lib/release-common.sh"

TAG="$(version_tag)"
DMG_FILE="$(dmg_name)"
DMG_FULL="$(dmg_path)"

echo "=== Publishing appcast for ${APP_NAME} ${TAG} ==="

# ─── Validate ────────────────────────────────────────────────────────────────
if [ ! -f "$DMG_FULL" ]; then
    log_fail "DMG not found: ${DMG_FULL}"
    echo "  Run ./scripts/build-dmg.sh first."
    exit 1
fi

GENERATE_APPCAST="$(resolve_generate_appcast)"
log_pass "generate_appcast found: ${GENERATE_APPCAST}"

THINKUR_WEB_DIR="$(resolve_thinkur_web)"
log_pass "thinkur-web repo found: ${THINKUR_WEB_DIR}"

# ─── Generate appcast.xml ────────────────────────────────────────────────────
log_step "Generating appcast.xml..."

# Create a staging directory with the DMG for appcast generation
APPCAST_STAGING="${BUILD_DIR}/appcast_staging"
rm -rf "${APPCAST_STAGING}"
mkdir -p "${APPCAST_STAGING}"
cp "${DMG_FULL}" "${APPCAST_STAGING}/"

# If RELEASE_NOTES.md exists, convert to HTML for Sparkle release notes.
# Sparkle's generate_appcast picks up *.html files named to match the DMG.
RELEASE_NOTES_FILE="${PROJECT_DIR}/RELEASE_NOTES.md"
if [ -f "${RELEASE_NOTES_FILE}" ]; then
    SPARKLE_NOTES_NAME="${DMG_FILE%.dmg}.html"
    echo "  Creating Sparkle release notes: ${SPARKLE_NOTES_NAME}"
    # Simple Markdown→HTML conversion (handles headers, bold, lists)
    sed -E \
        -e 's/^## (.+)/<h2>\1<\/h2>/' \
        -e 's/\*\*([^*]+)\*\*/<strong>\1<\/strong>/g' \
        -e 's/^- (.+)/<li>\1<\/li>/' \
        "${RELEASE_NOTES_FILE}" \
        | awk '
            BEGIN { in_list=0 }
            /<li>/ { if (!in_list) { print "<ul>"; in_list=1 } }
            !/<li>/ && !/<\/li>/ && in_list { print "</ul>"; in_list=0 }
            { print }
            END { if (in_list) print "</ul>" }
        ' > "${APPCAST_STAGING}/${SPARKLE_NOTES_NAME}"
fi

# Generate appcast — download URL points to the GitHub Release asset
"${GENERATE_APPCAST}" \
    --download-url-prefix "https://github.com/${GITHUB_REPO}/releases/download/${TAG}/" \
    "${APPCAST_STAGING}"

APPCAST_FILE="${APPCAST_STAGING}/appcast.xml"

if [ ! -f "${APPCAST_FILE}" ]; then
    log_fail "appcast.xml was not generated"
    exit 1
fi

log_pass "appcast.xml generated"

# ─── Update thinkur-web ─────────────────────────────────────────────────────
log_step "Updating thinkur-web repo..."

# Copy appcast.xml into the web repo's public directory
# Vite copies public/ files as-is to dist/
mkdir -p "${THINKUR_WEB_DIR}/public"
cp "${APPCAST_FILE}" "${THINKUR_WEB_DIR}/public/appcast.xml"

# Commit and push
cd "${THINKUR_WEB_DIR}"
git add public/appcast.xml
git commit -m "Update appcast.xml for ${TAG}" || echo "  (no changes to commit)"
git push

log_pass "appcast.xml pushed to thinkur-web"

# ─── Publish draft release ───────────────────────────────────────────────────
log_step "Publishing draft release ${TAG}..."
gh release edit "${TAG}" \
    --repo "${GITHUB_REPO}" \
    --draft=false \
    2>/dev/null \
    && log_pass "Release ${TAG} published" \
    || log_warn "Could not update draft (may already be published)"

echo ""
echo "=== Done ==="
echo "Release: https://github.com/${GITHUB_REPO}/releases/tag/${TAG}"
echo "Appcast: https://thinkur.app/appcast.xml (after Pages deploy)"
