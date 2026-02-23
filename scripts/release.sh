#!/usr/bin/env bash
set -euo pipefail

# ─── thinkur release orchestrator ────────────────────────────────────────────
# One command for a full release, or pick individual steps.
#
# Usage:
#   ./scripts/release.sh patch              # full release
#   ./scripts/release.sh minor              # full release, minor bump
#   ./scripts/release.sh major              # full release, major bump
#   ./scripts/release.sh --step preflight   # just check readiness
#   ./scripts/release.sh --step build       # just build DMG
#   ./scripts/release.sh --step publish     # just publish (re-publish after failure)

# ─── Setup ───────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "${PROJECT_DIR}"

# Prevent stale GITHUB_TOKEN from blocking gh CLI keyring auth
unset GITHUB_TOKEN 2>/dev/null || true

# ─── Parse arguments ─────────────────────────────────────────────────────────
STEP=""
BUMP_TYPE=""

if [ $# -eq 0 ]; then
    echo "Usage:"
    echo "  $0 patch|minor|major          Full release with version bump"
    echo "  $0 --step preflight           Just run pre-flight checks"
    echo "  $0 --step build               Just build DMG"
    echo "  $0 --step publish             Just publish (GitHub Release + appcast)"
    exit 1
fi

if [ "$1" = "--step" ]; then
    if [ $# -lt 2 ]; then
        echo "Error: --step requires an argument: preflight, build, or publish"
        exit 1
    fi
    STEP="$2"
    if [[ ! "$STEP" =~ ^(preflight|build|publish)$ ]]; then
        echo "Error: unknown step '$STEP' — use preflight, build, or publish"
        exit 1
    fi
elif [[ "$1" =~ ^(major|minor|patch)$ ]]; then
    BUMP_TYPE="$1"
else
    echo "Error: unknown argument '$1'"
    echo "Use patch|minor|major for full release, or --step <step> for individual steps."
    exit 1
fi

# ─── Step runners ────────────────────────────────────────────────────────────
step_preflight() {
    "${SCRIPT_DIR}/release-preflight.sh"
}

step_bump() {
    local bump="$1"
    echo ""
    echo "=== Step: Bump Version (${bump}) ==="

    "${SCRIPT_DIR}/bump-version.sh" "$bump"

    echo "→ Running xcodegen generate..."
    xcodegen generate --quiet 2>/dev/null || xcodegen generate

    local new_version
    new_version=$(grep 'MARKETING_VERSION:' "${PROJECT_DIR}/project.yml" | head -1 | sed 's/.*"\(.*\)"/\1/')

    echo "→ Committing version bump..."
    git add project.yml thinkur.xcodeproj
    git commit -m "Release v${new_version}"
    git tag "v${new_version}"

    echo "  ✓ Committed and tagged v${new_version}"
}

step_build() {
    echo ""
    echo "=== Step: Build DMG ==="
    "${SCRIPT_DIR}/build-dmg.sh"
}

step_push() {
    echo ""
    echo "=== Step: Push ==="
    echo "→ Pushing to origin main with tags..."
    git push origin main --tags
    echo "  ✓ Pushed"
}

step_publish() {
    echo ""
    echo "=== Step: Publish ==="
    "${SCRIPT_DIR}/publish-release.sh"
}

# ─── Single step mode ────────────────────────────────────────────────────────
if [ -n "$STEP" ]; then
    case "$STEP" in
        preflight) step_preflight ;;
        build)     step_build ;;
        publish)   step_publish ;;
    esac
    exit 0
fi

# ─── Full release mode ──────────────────────────────────────────────────────
CURRENT_VERSION=$(grep 'MARKETING_VERSION:' "${PROJECT_DIR}/project.yml" | head -1 | sed 's/.*"\(.*\)"/\1/')

echo "=== thinkur Release ==="
echo ""
echo "  Current version: ${CURRENT_VERSION}"
echo "  Bump type:       ${BUMP_TYPE}"
echo "  Steps:           preflight → bump → build → push → publish"
echo ""
read -r -p "Proceed? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

step_preflight
step_bump "$BUMP_TYPE"
step_build
step_push
step_publish

echo ""
echo "========================================"
echo "  Release complete!"
echo "========================================"
