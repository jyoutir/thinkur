# thinkur

> **NEVER run `xcodebuild`, `swift build`, or ANY build/compile command from `~/Downloads/thinkur`.** macOS Sequoia adds `com.apple.macl` + `com.apple.provenance` extended attributes when build tools touch files in `~/Downloads`. These xattrs are enforced at kernel level and **cannot be removed** — even `sudo xattr -cr` fails. The entire directory becomes permanently inaccessible to Terminal, editors, git, and all CLI tools. The only recovery is to delete the folder in Finder and re-clone. See `docs/building.md` for how to build safely.

Offline macOS menu bar voice typing app. Tap a hotkey to start recording, tap again to stop, transcribed text pastes at cursor. 100% local — WhisperKit on CoreML, no cloud.

## Build

```sh
# If new source files were added, regenerate Xcode project first:
xcodegen generate

# Build (always use -quiet to avoid flooding context):
xcodebuild -project thinkur.xcodeproj -scheme thinkur -configuration Debug build -quiet
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
    ├── release.sh              ← orchestrator: full release or individual steps
    ├── release-preflight.sh    ← pre-flight checks
    ├── bump-version.sh         ← version bump
    ├── build-dmg.sh            ← archive → sign → notarize → DMG
    ├── publish-release.sh      ← GitHub Release + appcast
    ├── reset-for-testing.sh    ← wipe local state for testing
    └── create-lifetime-key.sh  ← gift codes via LemonSqueezy
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

## Critical Rules

- **NEVER edit thinkur.xcodeproj directly.** Edit `project.yml` and run `xcodegen generate`.
- **Run `xcodegen generate` after adding/removing/moving source files.** Then verify with `xcodebuild -quiet`. `swift build` won't catch missing xcodegen entries.
- **Always use `-quiet` with xcodebuild.** Raw output floods context.
- **Permissions are on `/Applications/thinkur.app`**, not the DerivedData build.

## Gotchas

- AVAudioEngine inputNode format is hardware native (48kHz) — MUST use AVAudioConverter
- CGEvent tap returns nil without Accessibility permission — use as permission check
- CGEvent tap needs BOTH Accessibility AND Input Monitoring permissions
- NSPanel needs `.nonactivatingPanel` + `hidesOnDeactivate = false` for menu bar apps
- Check `keyboardEventAutorepeat` to avoid retriggering on hold
- Clipboard restore delay (150ms) may be too short for slow Electron apps
- ICU regex in raw strings: use `\u2014` NOT `\u{2014}` (Swift raw strings skip `\u{...}` escapes)
