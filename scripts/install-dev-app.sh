#!/usr/bin/env bash
set -euo pipefail

# ─── install-dev-app.sh ─────────────────────────────────────────────────────
# Called from Xcode post-build action (Debug only).
# Copies the built "thinkur Dev.app" to ~/Applications for side-by-side use.
#
# Usage (from Xcode post-action):
#   "${PROJECT_DIR}/scripts/install-dev-app.sh" "${BUILT_PRODUCTS_DIR}/${FULL_PRODUCT_NAME}"

APP_SOURCE="${1:?Usage: install-dev-app.sh <path-to-built-app>}"
APP_NAME="$(basename "$APP_SOURCE")"
DEST_DIR="${HOME}/Applications"
DEST_PATH="${DEST_DIR}/${APP_NAME}"

# Create ~/Applications if needed
mkdir -p "$DEST_DIR"

# Kill running instance gracefully (if any)
APP_PROCESS="${APP_NAME%.app}"
if pgrep -xq "$APP_PROCESS" 2>/dev/null; then
    killall "$APP_PROCESS" 2>/dev/null || true
    sleep 0.5
fi

# Copy built app to ~/Applications
ditto "$APP_SOURCE" "$DEST_PATH"

echo "Installed ${APP_NAME} → ${DEST_PATH}"
