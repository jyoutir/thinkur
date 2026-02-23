#!/usr/bin/env bash
set -euo pipefail

# ─── Pre-flight checks for thinkur release ──────────────────────────────────
# Run standalone or as part of release.sh
# Validates tools, auth, signing, and repo state before any work begins.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

PASS=0
FAIL=0
WARN=0

pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }
warn() { echo "  ⚠ $1"; WARN=$((WARN + 1)); }

echo "=== Release Pre-flight Checks ==="
echo ""

# ─── Required tools ──────────────────────────────────────────────────────────
echo "Tools:"
for tool in xcodegen create-dmg gh xcrun; do
    if command -v "$tool" &>/dev/null; then
        pass "$tool found"
    else
        fail "$tool not found — install it before releasing"
    fi
done

# ─── gh auth (with GITHUB_TOKEN unset to test keyring auth) ─────────────────
echo ""
echo "GitHub auth:"
(
    unset GITHUB_TOKEN 2>/dev/null || true
    if gh auth status &>/dev/null; then
        pass "gh authenticated via keyring"
    else
        fail "gh not authenticated — run: gh auth login"
    fi
)

# ─── Signing identity ───────────────────────────────────────────────────────
echo ""
echo "Code signing:"
if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    pass "Developer ID Application signing identity found"
else
    fail "Developer ID Application identity not in keychain"
fi

# ─── generate_appcast (Sparkle tool) ─────────────────────────────────────────
echo ""
echo "Sparkle:"
GENERATE_APPCAST=$(find ~/Library/Developer/Xcode/DerivedData -name "generate_appcast" -type f 2>/dev/null | head -1)
if [ -n "${GENERATE_APPCAST}" ]; then
    pass "generate_appcast found: ${GENERATE_APPCAST}"
else
    fail "generate_appcast not found in DerivedData — build project in Xcode first"
fi

# ─── thinkur-web repo ───────────────────────────────────────────────────────
echo ""
echo "thinkur-web:"
THINKUR_WEB_DIR="${THINKUR_WEB_DIR:-$(cd "${PROJECT_DIR}/.." && pwd)/thinkur-web}"
if [ -d "${THINKUR_WEB_DIR}/.git" ]; then
    pass "thinkur-web repo found at ${THINKUR_WEB_DIR}"
else
    fail "thinkur-web repo not found at ${THINKUR_WEB_DIR} — set THINKUR_WEB_DIR or clone it"
fi

# ─── Git state ───────────────────────────────────────────────────────────────
echo ""
echo "Git:"
cd "${PROJECT_DIR}"

if [ -z "$(git status --porcelain)" ]; then
    pass "working tree is clean"
else
    fail "working tree has uncommitted changes — commit or stash first"
fi

BRANCH=$(git branch --show-current)
if [ "$BRANCH" = "main" ]; then
    pass "on main branch"
else
    warn "on branch '${BRANCH}' (not main)"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "─────────────────────────────────"
echo "  ${PASS} passed, ${FAIL} failed, ${WARN} warnings"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "Fix the failures above before releasing."
    exit 1
fi

echo "  Ready to release."
