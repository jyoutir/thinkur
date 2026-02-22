#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID="com.jyo.thinkur"
APP_NAME="thinkur"
APP_PATH="/Applications/${APP_NAME}.app"

echo "=== Resetting ${APP_NAME} for fresh install testing ==="

# Quit the app if running
killall "$APP_NAME" 2>/dev/null || true
sleep 1

# Reset TCC permissions (microphone, accessibility, input monitoring)
for service in Microphone Accessibility ListenEvent SpeechRecognition; do
    tccutil reset "$service" "$BUNDLE_ID" 2>/dev/null || true
    sudo tccutil reset "$service" "$BUNDLE_ID" 2>/dev/null || true
done
echo "✓ Permissions reset"

# Remove preferences and caches
defaults delete "$BUNDLE_ID" 2>/dev/null || true
rm -f ~/Library/Preferences/${BUNDLE_ID}.plist
# Restart preferences daemon to flush cache (auto-respawns immediately)
killall cfprefsd 2>/dev/null || true
rm -rf ~/Library/Application\ Support/${BUNDLE_ID}
rm -rf ~/Library/Application\ Support/${APP_NAME}
rm -rf ~/Library/Caches/${BUNDLE_ID}
rm -rf ~/Library/Saved\ Application\ State/${BUNDLE_ID}.savedState
rm -rf ~/Library/HTTPStorages/${BUNDLE_ID} 2>/dev/null
echo "✓ Preferences and caches cleared"

# Unregister from LaunchServices
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREGISTER" -u "$APP_PATH" 2>/dev/null || true
echo "✓ LaunchServices unregistered"

# Remove the app
rm -rf "$APP_PATH"
echo "✓ App removed from /Applications"

echo ""
echo "=== Done. Next steps: ==="
echo "1. Mount the DMG:  open build/${APP_NAME}-*.dmg"
echo "2. Drag ${APP_NAME}.app to /Applications"
echo "3. Launch — you should see Gatekeeper + all permission prompts"
