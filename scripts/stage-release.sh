#!/usr/bin/env bash
set -euo pipefail

# ─── stage-release.sh ────────────────────────────────────────────────────────
# Creates (or updates) a GitHub DRAFT release with the DMG attached.
# Does NOT update the appcast — use publish-appcast.sh for that.

source "$(dirname "$0")/lib/release-common.sh"

TAG="$(version_tag)"
DMG_FILE="$(dmg_name)"
DMG_FULL="$(dmg_path)"

echo "=== Staging ${APP_NAME} ${TAG} (draft) ==="

# ─── Validate ────────────────────────────────────────────────────────────────
if [ ! -f "$DMG_FULL" ]; then
    log_fail "DMG not found: ${DMG_FULL}"
    echo "  Run ./scripts/build-dmg.sh first."
    exit 1
fi

# ─── Create draft GitHub Release ─────────────────────────────────────────────
log_step "Creating draft GitHub Release ${TAG}..."

RELEASE_NOTES_FILE="${PROJECT_DIR}/RELEASE_NOTES.md"
if [ -f "$RELEASE_NOTES_FILE" ]; then
    echo "  Using RELEASE_NOTES.md"
    gh release create "$TAG" \
        --repo "$GITHUB_REPO" \
        --title "${APP_NAME} ${TAG}" \
        --notes-file "$RELEASE_NOTES_FILE" \
        --draft \
        "$DMG_FULL"
else
    echo "  No RELEASE_NOTES.md found, using generic notes"
    gh release create "$TAG" \
        --repo "$GITHUB_REPO" \
        --title "${APP_NAME} ${TAG}" \
        --notes "Release ${TAG}" \
        --draft \
        "$DMG_FULL"
fi

log_pass "Draft release created with DMG attached"

echo ""
echo "=== Next Steps ==="
echo "  1. Verify the draft release: https://github.com/${GITHUB_REPO}/releases"
echo "  2. Download the DMG from the draft and test it on a clean machine"
echo "  3. When satisfied, publish the appcast:"
echo "     ./scripts/release.sh publish"
echo ""
echo "  The release is NOT visible to Sparkle users until you run publish."
