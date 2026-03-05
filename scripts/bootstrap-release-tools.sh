#!/usr/bin/env bash
set -euo pipefail

# ─── bootstrap-release-tools.sh ─────────────────────────────────────────────
# Downloads Sparkle 2.8.0 and caches generate_appcast + sign_update.
# Idempotent — skips if already cached.

SPARKLE_VERSION="2.8.0"
CACHE_DIR="${HOME}/.cache/thinkur/tools/sparkle-${SPARKLE_VERSION}"
BIN_DIR="${CACHE_DIR}/bin"

if [ -x "${BIN_DIR}/generate_appcast" ] && [ -x "${BIN_DIR}/sign_update" ]; then
    echo "Sparkle ${SPARKLE_VERSION} tools already cached at ${BIN_DIR}"
    echo "  generate_appcast: $(${BIN_DIR}/generate_appcast --version 2>&1 || echo 'ok')"
    exit 0
fi

echo "=== Bootstrapping Sparkle ${SPARKLE_VERSION} tools ==="

DOWNLOAD_URL="https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"
TEMP_DIR=$(mktemp -d /tmp/sparkle-bootstrap-XXXX)

cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT

echo "→ Downloading Sparkle ${SPARKLE_VERSION}..."
curl -fsSL "$DOWNLOAD_URL" -o "${TEMP_DIR}/Sparkle.tar.xz"

echo "→ Extracting..."
tar -xf "${TEMP_DIR}/Sparkle.tar.xz" -C "$TEMP_DIR"

echo "→ Caching tools to ${BIN_DIR}..."
mkdir -p "$BIN_DIR"

# The tools are in bin/ inside the extracted archive
for tool in generate_appcast sign_update; do
    if [ -f "${TEMP_DIR}/bin/${tool}" ]; then
        cp "${TEMP_DIR}/bin/${tool}" "${BIN_DIR}/${tool}"
        chmod +x "${BIN_DIR}/${tool}"
        echo "  ✓ ${tool}"
    else
        echo "  ✗ ${tool} not found in archive"
        exit 1
    fi
done

echo ""
echo "=== Done ==="
echo "Tools cached at: ${BIN_DIR}"
