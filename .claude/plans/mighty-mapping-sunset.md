# Plan: Multi-Engine Model Selection (3 Models for Testing)

## Context

thinkur auto-selects WhisperKit models by RAM with no user control. We want to expose 3 models for A/B testing so the user can pick the best speed/accuracy tradeoff. Research shows Parakeet-TDT is 10-100x faster than WhisperKit with competitive accuracy.

## Models

| # | Model | Engine | Speed (10s audio) | Size |
|---|-------|--------|-------------------|------|
| 1 | `small.en` | WhisperKit | ~1-3s | ~466MB |
| 2 | `large-v3_turbo` | WhisperKit | ~1-2s | ~954MB |
| 3 | Parakeet v2 | FluidAudio | ~50-80ms | ~600MB |

Default: `small.en` (current quick-start behavior).

## Architecture

**`TranscriptionRouter`** implements `Transcribing` protocol and delegates to the active engine. `RecordingCoordinator` already accepts `any Transcribing` — no changes needed there beyond post-processing logic.

**`ParakeetTranscriptionEngine`** implements `Transcribing` using FluidAudio's `AsrManager`.

When Parakeet is active, auto-disable `SpokenPunctuation`, `PausePunctuation`, `Capitalization` processors (Parakeet handles these natively).

## Implementation Steps

### 1. Add FluidAudio dependency
**Files:** `Package.swift`, `project.yml`
- Add `FluidAudio` SPM package (from: `"0.7.9"`)

### 2. Create TranscriptionModel enum
**New:** `Sources/thinkur/Models/TranscriptionModel.swift`
- 3 cases: `.whisperSmall`, `.whisperTurbo`, `.parakeetV2`
- Properties: `displayName`, `isParakeet`, `engineType`, `whisperKitModelName`

### 3. Add setting to SettingsManager
**Edit:** `Sources/thinkur/Core/SettingsManager.swift`
- Add `selectedModel: String` (raw value, default `"whisperSmall"`)

### 4. Create ParakeetTranscriptionEngine
**New:** `Sources/thinkur/Core/ParakeetTranscriptionEngine.swift`
- Implements `Transcribing` using FluidAudio `AsrManager`
- `loadModel()` → `AsrModels.downloadAndLoad(version: .v2)` + `asrManager.initialize()`
- `transcribe()` → `asrManager.transcribe(samples)` → returns `result.text`
- Maps token timings → `[WordTimingInfo]` if available, else empty

### 5. Create TranscriptionRouter
**New:** `Sources/thinkur/Core/TranscriptionRouter.swift`
- `@MainActor @Observable` class implementing `Transcribing`
- Holds `activeEngine: any Transcribing`, delegates all protocol methods
- `switchEngine()` for hot-swapping

### 6. Update ModelLoadCoordinator
**Edit:** `Sources/thinkur/Core/Coordinators/ModelLoadCoordinator.swift`
- Accept `TranscriptionRouter` + both engine instances
- New `loadModel(for: TranscriptionModel)` — loads correct engine, calls `router.switchEngine()`
- Remove background upgrade when user has explicitly selected a model

### 7. Update ServiceContainer
**Edit:** `Sources/thinkur/Core/DI/ServiceContainer.swift`
- Create `TranscriptionRouter` wrapping `TranscriptionEngine`
- Add `parakeetEngine: ParakeetTranscriptionEngine`
- Add `transcriptionRouter: TranscriptionRouter`

### 8. Update AppCoordinator
**Edit:** `Sources/thinkur/Core/AppCoordinator.swift`
- Add `switchModel(_ model: TranscriptionModel)` method
- Pass router to `ModelLoadCoordinator`

### 9. Update RecordingCoordinator post-processing
**Edit:** `Sources/thinkur/Core/Coordinators/RecordingCoordinator.swift`
- Check if current model `isParakeet` → auto-disable SpokenPunctuation, PausePunctuation, Capitalization
- Accept settings reference to read `selectedModel`

### 10. Add Model Selection UI
**Edit:** `Sources/thinkur/UI/Pages/DictationSettingsView.swift`
- Add "Voice Model" `GroupedSettingsSection` with 3 selectable rows
- Show model name, speed label, download/loading state
- Note when Parakeet selected: "Includes built-in punctuation"

### 11. Regenerate Xcode project
- `xcodegen generate`

## Files Summary

| Action | File |
|--------|------|
| Edit | `Package.swift` |
| Edit | `project.yml` |
| **New** | `Sources/thinkur/Models/TranscriptionModel.swift` |
| **New** | `Sources/thinkur/Core/ParakeetTranscriptionEngine.swift` |
| **New** | `Sources/thinkur/Core/TranscriptionRouter.swift` |
| Edit | `Sources/thinkur/Core/SettingsManager.swift` |
| Edit | `Sources/thinkur/Core/Coordinators/ModelLoadCoordinator.swift` |
| Edit | `Sources/thinkur/Core/DI/ServiceContainer.swift` |
| Edit | `Sources/thinkur/Core/AppCoordinator.swift` |
| Edit | `Sources/thinkur/Core/Coordinators/RecordingCoordinator.swift` |
| Edit | `Sources/thinkur/UI/Pages/DictationSettingsView.swift` |

## Verification
1. `xcodegen generate && xcodebuild -project thinkur.xcodeproj -scheme thinkur -configuration Debug build -quiet`
2. `swift test`
3. Manual: Settings → select each model → verify download + load → record → compare output
