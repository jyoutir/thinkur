#!/usr/bin/env bash
set -euo pipefail

# ─── thinkur release orchestrator ────────────────────────────────────────────
# Two verbs:
#   ./scripts/release.sh prepare patch|minor|major
#       → preflight → bump → xcodegen → commit → tag → build DMG → push → stage draft
#   ./scripts/release.sh publish
#       → generate appcast → push to thinkur-web → publish draft release

source "$(dirname "$0")/lib/release-common.sh"

# ─── Parse arguments ─────────────────────────────────────────────────────────
if [ $# -eq 0 ]; then
    echo "Usage:"
    echo "  $0 prepare patch|minor|major   Prepare a release (build + stage draft)"
    echo "  $0 publish                     Publish appcast + release (makes it live)"
    exit 1
fi

VERB="$1"
shift

case "$VERB" in
    prepare)
        if [ $# -lt 1 ] || [[ ! "$1" =~ ^(major|minor|patch)$ ]]; then
            echo "Usage: $0 prepare patch|minor|major"
            exit 1
        fi
        BUMP_TYPE="$1"
        ;;
    publish)
        ;;
    *)
        echo "Error: unknown verb '$VERB' — use 'prepare' or 'publish'"
        exit 1
        ;;
esac

# ─── prepare ─────────────────────────────────────────────────────────────────
if [ "$VERB" = "prepare" ]; then
    CURRENT_VERSION="$(read_version)"

    echo "=== thinkur Release — Prepare ==="
    echo ""
    echo "  Current version: ${CURRENT_VERSION}"
    echo "  Bump type:       ${BUMP_TYPE}"
    echo "  Steps:           preflight → bump → xcodegen → commit → tag → build DMG → push → stage draft"
    echo ""
    read -r -p "Proceed? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi

    # 1. Preflight
    "${SCRIPT_DIR}/release-preflight.sh"

    # 2. Bump version
    echo ""
    echo "=== Step: Bump Version (${BUMP_TYPE}) ==="
    "${SCRIPT_DIR}/bump-version.sh" "$BUMP_TYPE"

    # 3. Regenerate Xcode project
    log_step "Running xcodegen generate..."
    cd "$PROJECT_DIR"
    xcodegen generate --quiet 2>/dev/null || xcodegen generate

    # 4. Commit + tag
    NEW_VERSION="$(read_version)"
    log_step "Committing version bump..."
    git add project.yml
    git add thinkur.xcodeproj 2>/dev/null || true
    git commit -m "Release v${NEW_VERSION}"
    git tag "v${NEW_VERSION}"
    log_pass "Committed and tagged v${NEW_VERSION}"

    # 5. Build DMG
    echo ""
    echo "=== Step: Build DMG ==="
    "${SCRIPT_DIR}/build-dmg.sh"

    # 6. Push
    echo ""
    echo "=== Step: Push ==="
    log_step "Pushing to origin main with tags..."
    git push origin main --tags
    log_pass "Pushed"

    # 7. Stage draft release
    echo ""
    echo "=== Step: Stage Draft Release ==="
    "${SCRIPT_DIR}/stage-release.sh"

    echo ""
    echo "========================================"
    echo "  Prepare complete!"
    echo "  Draft release staged for v${NEW_VERSION}"
    echo ""
    echo "  Next: validate the DMG, then run:"
    echo "    ./scripts/release.sh publish"
    echo "========================================"
fi

# ─── publish ─────────────────────────────────────────────────────────────────
if [ "$VERB" = "publish" ]; then
    echo "=== thinkur Release — Publish ==="
    "${SCRIPT_DIR}/publish-appcast.sh"

    echo ""
    echo "========================================"
    echo "  Release published!"
    echo "========================================"
fi
