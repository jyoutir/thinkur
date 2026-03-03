# LSUIElement & TextField Input on macOS 26 (Tahoe)

> **TL;DR: `LSUIElement` MUST be `true` in Info.plist. The dock icon is added at
> runtime via `NSApp.setActivationPolicy(.regular)`. Removing or setting
> `LSUIElement` to `false` breaks ALL TextField keyboard input on macOS 26.**

## The Bug

TextFields across the entire app silently drop all keyboard input. Clicking a
TextField shows a cursor/focus ring but typing does nothing. The console logs:

```
ViewBridge to RemoteViewService Terminated: Error Domain=com.apple.ViewBridge Code=18
"(null)" UserInfo={
  com.apple.ViewBridge.error.hint=this process disconnected remote view controller
    -- benign unless unexpected,
  com.apple.ViewBridge.error.description=NSViewBridgeErrorCanceled
}
```

Every TextField is affected: PaywallView (license key), ShortcutsView
(trigger/expansion), MeetingSetupView (API key), OnboardingStepView (hourly
rate), HotkeySettingsView, etc.

## Root Cause

macOS 26 Tahoe renders TextField text input via a **RemoteViewService** — an
out-of-process XPC helper (`TextInputUI.xpc`) connected through ViewBridge.
This is how Apple provides secure text input on Tahoe.

When `LSUIElement` is `false` (or absent from Info.plist), the app launches with
`.regular` activation policy. On macOS 26, regular apps have aggressive window
lifecycle management that **disconnects the ViewBridge** to the remote text
input service during the initial window setup. Once disconnected, the TextField
appears focused but the XPC backend is gone — keystrokes have nowhere to go.

When `LSUIElement` is `true`, the app launches with `.accessory` activation
policy. Accessory apps have lighter window management — macOS doesn't perform
the same ViewBridge lifecycle operations, so the remote text input service stays
connected.

## The Fix (commit history: removed Feb 28 2026, restored Mar 3 2026)

### 1. Info.plist — `LSUIElement` MUST be `true`

```xml
<key>LSUIElement</key>
<true/>
```

This makes the app start as an **accessory app** (no dock icon, no app menu).
The ViewBridge remote text input service connects properly under this policy.

### 2. AppDelegate — switch to `.regular` at runtime for dock icon

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    // ...duplicate instance check...

    // LSUIElement=true keeps the app as accessory (no dock icon) by default.
    // Switch to .regular so the dock icon shows. This ordering matters on
    // macOS 26 — starting as accessory avoids ViewBridge disconnections
    // that break TextField input in regular apps.
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
}
```

**The ordering is critical.** By the time `applicationDidFinishLaunching` runs,
SwiftUI has already set up the Window scene and the ViewBridge connections are
established under the safe `.accessory` policy. Switching to `.regular`
afterward gives us the dock icon without disrupting the existing ViewBridge
connections.

### 3. Window scene — `.defaultLaunchBehavior(.presented)`

```swift
Window("thinkur", id: "main") {
    // ...
}
.defaultLaunchBehavior(.presented)
```

Accessory apps don't auto-present their windows. This modifier tells SwiftUI to
show the main window on launch. Without it, the window won't appear.

## What NOT To Do

| Action | Result |
|--------|--------|
| Remove `LSUIElement` from Info.plist | App becomes `.regular` → ViewBridge dies → no TextField input |
| Set `LSUIElement` to `false` | Same as above |
| Remove `.defaultLaunchBehavior(.presented)` | Window won't show on launch (accessory apps don't auto-present) |
| Move `setActivationPolicy(.regular)` before window setup | ViewBridge connects under `.regular` policy → same breakage |

## Red Herrings (things that did NOT fix it)

These were investigated and ruled out during debugging:

- **Removing `.glassEffect()` modifiers** — Glass effects use ViewBridge too,
  but they're not the cause. TextFields break even with plain material
  backgrounds.
- **Removing `windowDidResignKey`** — The aggressive focus-stealing in
  `windowDidResignKey` (added in commit `8042242`) compounds the issue but is
  not the root cause. Removing it alone doesn't fix TextFields.
- **Removing `.defaultLaunchBehavior(.presented)`** — This is actually needed,
  not harmful.
- **Increasing HotkeyManager debounce** — The 500ms debounce for ViewBridge
  bounces is fine. The bounces are a symptom, not the cause.

## Timeline

| Date | Commit | What happened |
|------|--------|--------------|
| Feb 27 2026 | `0a58176` | Last working state. `LSUIElement=true`, runtime `setActivationPolicy(.regular)` if `showInDock` enabled. |
| Feb 28 2026 | `b43f2da` | **`LSUIElement=true` removed from Info.plist.** `showInDock` / `setActivationPolicy` code also removed. TextFields break. |
| Feb 28 2026 | `8042242` | `windowDidResignKey` added — makes it worse by stealing focus during ViewBridge recovery. |
| Mar 1 2026 | `2775982` | HotkeyManager rewritten (CGEvent tap → Carbon). Unrelated to TextField issue. |
| Mar 3 2026 | (working tree) | **Fix applied:** `LSUIElement=true` restored, `setActivationPolicy(.regular)` in AppDelegate, `.defaultLaunchBehavior(.presented)` restored. |

## How to Verify

1. Build in Xcode (Cmd+R)
2. Click any TextField — should accept keyboard input immediately
3. Check dock icon appears
4. Check console for ViewBridge errors — the "benign" message may still appear
   occasionally (that's fine), but TextFields must remain functional
