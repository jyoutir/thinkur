#!/bin/bash
# dev-permissions.sh — Reset TCC permissions and open System Settings panes
# Run this after a debug build if macOS stops recognizing thinkur's permissions.

set -euo pipefail

BUNDLE_ID="com.jyo.thinkur"

echo "Resetting TCC entries for $BUNDLE_ID..."
for svc in Microphone Accessibility ListenEvent; do
  tccutil reset "$svc" "$BUNDLE_ID" 2>/dev/null && echo "  ✓ Reset $svc" || echo "  – $svc (nothing to reset)"
done

echo ""
echo "Opening System Settings panes..."
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"

echo ""
echo "Next steps:"
echo "  1. In each Settings pane, toggle thinkur ON"
echo "  2. Build & run from Xcode (Cmd+R)"
echo "  3. If thinkur doesn't appear in a pane, run it once first — the OS registers it on first launch"
