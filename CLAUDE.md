# thinkur

> **NEVER run `xcodebuild`, `swift build`, or ANY build/compile command from `~/Downloads/thinkur`.** macOS Sequoia adds `com.apple.macl` + `com.apple.provenance` extended attributes when build tools touch files in `~/Downloads`. These xattrs are enforced at kernel level and **cannot be removed** — even `sudo xattr -cr` fails. The entire directory becomes permanently inaccessible to Terminal, editors, git, and all CLI tools. The only recovery is to delete the folder in Finder and re-clone. See `docs/building.md` for how to build safely.

Offline macOS menu bar voice typing app. Tap a hotkey to start recording, tap again to stop, transcribed text pastes at cursor. 100% local — WhisperKit on CoreML, no cloud.

## Build

Use Xcode (Cmd+R) for Debug builds, or the Xcode MCP bridge. Release: `scripts/build-dmg.sh`.

```sh
# If new source files were added, regenerate Xcode project first:
xcodegen generate
```

## Test

```sh
swift test
```

> `xcodebuild test` has a bootstrapping issue — always use `swift test`.

## Run

Run from Xcode (Cmd+R) or launch `/Applications/thinkur.app` directly. The app lives in the menu bar (no dock icon).

## Project Structure

```
thinkur/
├── project.yml                          ← xcodegen spec (source of truth for .xcodeproj)
├── Package.swift                        ← SPM deps
├── Sources/thinkur/
│   ├── thinkurApp.swift                 ← @main, MenuBarExtra
│   ├── Resources/
│   │   ├── Info.plist                   ← LSUIElement, usage descriptions
│   │   └── thinkur.entitlements         ← audio input, bluetooth, network
│   ├── Core/
│   │   ├── AppRuntimeConfiguration.swift        ← reads plist keys for dev/release split
│   │   ├── AppState/SharedAppState.swift        ← @Observable, single source of truth
│   │   ├── DI/ServiceContainer.swift            ← dependency injection container
│   │   ├── DI/ViewModelFactory.swift            ← creates view models with injected deps
│   │   ├── Coordinators/                        ← ModelLoadCoordinator, HotkeyCoordinator, RecordingCoordinator
│   │   ├── AudioCaptureManager.swift            ← AVAudioEngine → 16kHz mono Float32 + RMS
│   │   ├── TranscriptionEngine.swift            ← WhisperKit wrapper (large-v3)
│   │   ├── HotkeyManager.swift                  ← CGEvent tap, customizable hotkey
│   │   ├── TextInsertionService.swift           ← clipboard save → Cmd+V paste → restore
│   │   ├── PermissionManager.swift              ← Accessibility, Mic, Input Monitoring
│   │   ├── Processors/                          ← 9 post-processing processors
│   │   ├── PostProcessing/Rules/                ← static data (word lists, patterns)
│   │   ├── PostProcessing/Matchers/             ← reusable matching logic
│   │   ├── PostProcessing/Models/               ← ReplacementRule, PauseThresholds, etc.
│   │   ├── PostProcessing/Utilities/            ← RegexCache, TextMutator, NLTaggerHelper
│   │   └── Data/SwiftDataContainerFactory.swift ← SwiftData store setup
│   ├── UI/                                      ← SwiftUI views, floating panels
│   └── Utilities/                               ← Constants, Logger, FrontmostAppDetector
├── Tests/thinkurTests/
│   ├── Processors/    ← post-processing tests
│   ├── Services/      ← service layer tests
│   ├── ViewModels/    ← view model tests
│   ├── Mocks/         ← test doubles
│   ├── Integration/   ← integration tests
│   └── Utilities/     ← utility tests
└── scripts/
    ├── release.sh              ← orchestrator: prepare (build+stage) or publish
    ├── release-preflight.sh    ← pre-flight checks
    ├── bump-version.sh         ← version bump
    ├── build-dmg.sh            ← archive → sign → notarize → DMG
    ├── stage-release.sh        ← create/update draft GitHub Release with DMG
    ├── publish-appcast.sh      ← generate appcast → push → publish draft
    ├── bootstrap-release-tools.sh ← cache Sparkle tools to ~/.cache/thinkur/
    ├── install-dev-app.sh      ← post-build: copy Dev app to ~/Applications
    ├── dev-reset-permissions.sh ← manual TCC reset for dev bundle ID
    ├── reset-for-testing.sh    ← wipe local state for testing
    └── lib/
        └── release-common.sh   ← shared helpers for release scripts
```

## Architecture

```
Hotkey (CGEvent tap) → AudioCaptureManager (AVAudioEngine 16kHz)
                      → TranscriptionEngine (WhisperKit large-v3)
                      → TextPostProcessor (9-stage pipeline)
                      → TextInsertionService (clipboard Cmd+V)
                      → FloatingIndicatorPanel (waveform overlay while recording)
```

- **SharedAppState** is the single source of truth for app state, model readiness, transcription
- **ServiceContainer + ViewModelFactory** provide dependency injection
- **Tap-to-toggle**: hotkey once to start, again to stop and transcribe
- **Modifier keys pass through**: Cmd+Tab, Option+Tab, etc. work normally
- Hotkey is customizable via Settings

## Tech Stack

- **STT**: WhisperKit (large-v3, CoreML, on-device)
- **Audio**: AVAudioEngine + AVAudioConverter (hardware rate → 16kHz mono Float32)
- **Hotkey**: CGEvent tap (customizable key code via settings)
- **Text insertion**: NSPasteboard + CGEvent (Cmd+V)
- **UI**: SwiftUI (MenuBarExtra, waveform), AppKit (NSPanel)
- **Project gen**: xcodegen
- **Updates**: Sparkle (appcast.xml hosted on thinkur.app)
- **Signing**: Developer ID Application + notarization

## Dev vs Release

Two build configurations produce two distinct apps:

| | Debug (Dev) | Release |
|---|---|---|
| Bundle ID | `com.jyo.thinkur.dev` | `com.jyo.thinkur` |
| App name | thinkur Dev | thinkur |
| Sparkle | Disabled | Enabled |
| Telemetry | Disabled | Enabled |
| App Support | `~/Library/Application Support/thinkur-dev/` | `~/Library/Application Support/thinkur/` |
| Hue keychain | `com.jyo.thinkur.dev.hue` | `com.jyo.thinkur.hue` |
| Install location | `~/Applications/thinkur Dev.app` (post-action) | `/Applications/thinkur.app` |

`AppRuntimeConfiguration` reads custom plist keys (set via `project.yml` build settings) to drive all runtime differences.

## Critical Rules

- **NEVER remove or change `LSUIElement=true` in Info.plist.** macOS 26 Tahoe breaks ALL TextField keyboard input when the app launches as a regular app (`LSUIElement=false` or absent). The dock icon is added at runtime via `NSApp.setActivationPolicy(.regular)` in AppDelegate. See `docs/lsuielement-textfield-fix.md` for the full post-mortem.

- **NEVER edit thinkur.xcodeproj directly.** Edit `project.yml` and run `xcodegen generate`.
- **Run `xcodegen generate` after adding/removing/moving source files.** Then verify with an Xcode build (Cmd+R) or Xcode MCP bridge. `swift build` won't catch missing xcodegen entries.
- **Run `xcodegen generate` after editing schemes or build actions in `project.yml`.** Pre/post actions, test targets, and archive config all live in the `schemes:` section.
- **Always use `-quiet` with xcodebuild.** Raw output floods context.
- **Permissions are on the DerivedData build.** The post-build action installs the Dev app to `~/Applications`. Run `scripts/dev-reset-permissions.sh` manually if TCC gets stale.

## Xcode MCP Bridge

Claude Code connects to the running Xcode process via Apple's MCP bridge (`xcrun mcpbridge`). This is configured in `.claude.json` and available automatically each session.

**Why it matters:** We can't run `xcodebuild` from `~/Downloads/thinkur` (provenance xattr issue). The MCP bridge talks to Xcode's build engine directly — builds happen in DerivedData, bypassing the restriction entirely.

**What it can do:**
- Build the project and get structured diagnostics (errors + warnings with file:line)
- Run tests and get pass/fail results
- Query project structure, targets, build settings, and schemes
- Get compiler fix-it suggestions
- Resolve Swift package dependencies

**Requirements:**
- Xcode must be running with the project open
- Xcode Settings → Intelligence → "Enable Model Context Protocol" must be checked
- Claude Code session must be started (or restarted) after the MCP was added

**Prefer MCP over shell for builds.** Use the Xcode MCP tools for building, testing, and diagnostics instead of running `xcodebuild` in the terminal. Fall back to `xcodegen generate` in the shell (that's safe — it's not a build command).

## Gotchas

- AVAudioEngine inputNode format is hardware native (48kHz) — MUST use AVAudioConverter
- CGEvent tap returns nil without Accessibility permission — use as permission check
- CGEvent tap needs BOTH Accessibility AND Input Monitoring permissions
- NSPanel needs `.nonactivatingPanel` + `hidesOnDeactivate = false` for menu bar apps
- Check `keyboardEventAutorepeat` to avoid retriggering on hold
- Clipboard restore delay (150ms) may be too short for slow Electron apps
- ICU regex in raw strings: use `\u2014` NOT `\u{2014}` (Swift raw strings skip `\u{...}` escapes)
