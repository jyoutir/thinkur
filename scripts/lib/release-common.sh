#!/usr/bin/env bash
# ─── release-common.sh ──────────────────────────────────────────────────────
# Shared helpers for all release scripts. Source this, don't execute it.
# Usage: source "$(dirname "$0")/lib/release-common.sh"

set -euo pipefail

# ─── Paths ──────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")" && pwd -P)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_YML="${PROJECT_DIR}/project.yml"
BUILD_DIR="${PROJECT_DIR}/build"

# ─── Constants ──────────────────────────────────────────────────────────────
APP_NAME="thinkur"
GITHUB_REPO="jyoutir/thinkur-web"
TEAM_ID="${THINKUR_TEAM_ID:?Set THINKUR_TEAM_ID to your Apple Developer Team ID}"
NOTARIZE_PROFILE="${THINKUR_NOTARIZE_PROFILE:-thinkur-notarize}"
SPARKLE_TOOLS_DIR="${HOME}/.cache/thinkur/tools"

# ─── Version reading ───────────────────────────────────────────────────────
read_version() {
    grep 'MARKETING_VERSION:' "$PROJECT_YML" | head -1 | sed 's/.*"\(.*\)"/\1/'
}

read_build_number() {
    grep 'CURRENT_PROJECT_VERSION:' "$PROJECT_YML" | head -1 | sed 's/.*"\(.*\)"/\1/'
}

version_tag() {
    echo "v$(read_version)"
}

dmg_name() {
    echo "${APP_NAME}-$(read_version).dmg"
}

dmg_path() {
    echo "${BUILD_DIR}/$(dmg_name)"
}

# ─── Logging ────────────────────────────────────────────────────────────────
log_step() { echo "→ $1"; }
log_pass() { echo "  ✓ $1"; }
log_fail() { echo "  ✗ $1"; }
log_warn() { echo "  ⚠ $1"; }

# ─── Git helpers ────────────────────────────────────────────────────────────
require_clean_tree() {
    cd "$PROJECT_DIR"
    if [ -n "$(git status --porcelain)" ]; then
        log_fail "Working tree has uncommitted changes — commit or stash first"
        exit 1
    fi
}

# ─── GitHub token cleanup ──────────────────────────────────────────────────
# Prevents stale GITHUB_TOKEN from blocking gh CLI keyring auth
unset_github_token() {
    unset GITHUB_TOKEN 2>/dev/null || true
}

# ─── thinkur-web repo ──────────────────────────────────────────────────────
resolve_thinkur_web() {
    local dir="${THINKUR_WEB_DIR:-$(cd "${PROJECT_DIR}/.." && pwd)/thinkur-web}"
    if [ ! -d "${dir}/.git" ]; then
        log_fail "thinkur-web repo not found at ${dir} — set THINKUR_WEB_DIR or clone it"
        exit 1
    fi
    echo "$dir"
}

# ─── Sparkle generate_appcast ──────────────────────────────────────────────
resolve_generate_appcast() {
    # 1. Check override env var
    if [ -n "${SPARKLE_GENERATE_APPCAST:-}" ] && [ -x "$SPARKLE_GENERATE_APPCAST" ]; then
        echo "$SPARKLE_GENERATE_APPCAST"
        return
    fi
    # 2. Check cached tools
    local cached
    cached=$(find "${SPARKLE_TOOLS_DIR}" -name "generate_appcast" -type f 2>/dev/null | head -1)
    if [ -n "$cached" ] && [ -x "$cached" ]; then
        echo "$cached"
        return
    fi
    log_fail "generate_appcast not found. Run: ./scripts/bootstrap-release-tools.sh"
    exit 1
}

# Always unset stale GitHub token when sourcing
unset_github_token
