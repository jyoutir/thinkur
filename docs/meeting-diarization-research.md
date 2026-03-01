# Meeting Pipeline And Diarization Research Brief

Research date: `2026-02-28`

Conventions used in this brief:

- `Observed in code`: directly backed by local repository references.
- `Inference`: conclusion drawn from the observed implementation.
- `External research`: backed by external project documentation or papers.

## Executive Summary

The two objective functions are:

1. `speaker differentiation / stable speaker labels`
2. `transcript accuracy`

Chosen defaults for the next iteration:

- Optimize final output, not live labels.
- Optimize video calls first.
- Assume both 1:1 and group calls matter.

`Observed in code`: meeting recording is a separate mode from dictation, but the meeting path currently converts microphone audio to `16 kHz` mono, pulls system audio into another `16 kHz` mono stream, sums both into one mono waveform, and sends that mixed waveform through a live chunked ASR + diarization path before later replacing the result with a second offline diarization pass over the saved WAV. That means the app loses an obvious source boundary at capture time and also changes diarization strategy mid-meeting. The biggest current blocker is therefore not just "find a better diarization model"; it is the combination of the current capture topology and the split live/final pipeline. See [ViewModelFactory.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/DI/ViewModelFactory.swift#L17), [RecordingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/RecordingCoordinator.swift#L84), [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L55), [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L227), [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L266), [SystemAudioCaptureManager.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/SystemAudioCaptureManager.swift#L18), and [MeetingTranscriptionPipeline.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Meeting/MeetingTranscriptionPipeline.swift#L29).

## Current Meeting Flow

```mermaid
sequenceDiagram
    participant App as thinkurApp / RootView
    participant AC as AppCoordinator
    participant MV as MeetingsView
    participant MC as MeetingCoordinator
    participant PM as PermissionManager
    participant SCK as ScreenCaptureKit
    participant TAP as AudioTapProcessor
    participant SYS as SystemAudioCaptureManager
    participant PIPE as MeetingTranscriptionPipeline
    participant OFF as OfflineDiarizerManager
    participant MS as MeetingService
    participant MD as MeetingDetailView

    App->>AC: init()
    AC->>PM: checkAll()
    App->>MV: show Meetings tab after onboarding/license gates
    MV->>PM: checkScreenRecording()

    MV->>MC: startMeeting()
    MC->>PM: checkMicrophone()
    MC->>SCK: SCShareableContent...
    MC->>MC: load DiarizerManager
    MC->>MC: load OfflineDiarizerManager
    MC->>MC: load dedicated AsrManager(v3)
    MC->>SYS: startCapture()
    MC->>TAP: start AVAudioEngine tap

    loop Every 30 seconds
        TAP->>TAP: convert mic to 16 kHz mono
        SYS-->>TAP: read system samples
        TAP->>TAP: sum mic + system into one mono buffer
        TAP->>PIPE: drain current chunk
        PIPE->>PIPE: ASR on chunk
        PIPE->>PIPE: live diarization on chunk
        PIPE->>MC: attributed live segments
    end

    MC->>TAP: processCurrentChunk() on stop
    MC->>SYS: stopCapture()
    MC->>MC: finalize mixed WAV
    MC->>OFF: process(saved WAV)
    MC->>MC: retranscribe full WAV
    MC->>MC: merge token timings with offline speakers
    MC->>MS: save meeting record + segments + audio path
    MV->>MD: open saved meeting
    MD->>MD: render transcript, rename speakers, copy transcript
```

### Boot

`Observed in code`: the app boots through `thinkurApp`, injects a dedicated `MeetingViewModel` and `MeetingCoordinator`, and gates the root UI on onboarding completion and `permissionManager.allGranted`. `AppCoordinator` calls `permissionManager.checkAll()` synchronously so the root permission gate is already populated on first render. See [thinkurApp.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/thinkurApp.swift#L13), [thinkurApp.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/thinkurApp.swift#L48), [AppCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/AppCoordinator.swift#L31), and [AppCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/AppCoordinator.swift#L42).

`Observed in code`: meeting mode is separate from dictation mode. `ViewModelFactory` constructs a dedicated `RecordingCoordinator` for dictation and a separate `MeetingCoordinator` for meetings. `RecordingCoordinator.startRecording()` explicitly refuses to start dictation while `sharedState.isMeetingActive` is true. See [ViewModelFactory.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/DI/ViewModelFactory.swift#L17), [ViewModelFactory.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/DI/ViewModelFactory.swift#L45), and [RecordingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/RecordingCoordinator.swift#L84).

### Start

`Observed in code`: `MeetingsView` is the entry point for meeting UX. On task start, it checks screen recording permission and loads existing meetings. The "Start Meeting" button calls `viewModel.startMeeting()`. If screen recording is missing, the tab shows setup instead of the history/detail path. See [MeetingsView.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/UI/Pages/MeetingsView.swift#L9), [MeetingsView.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/UI/Pages/MeetingsView.swift#L22), and [MeetingsView.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/UI/Pages/MeetingsView.swift#L39).

`Observed in code`: meeting start hard-gates on microphone permission and ScreenCaptureKit access. `MeetingCoordinator.startMeeting()` first checks microphone permission, then directly calls `SCShareableContent.excludingDesktopWindows(...)` and aborts if that throws. Only after those checks does it load diarization models, the offline diarizer, and a dedicated meeting `AsrManager`, then create the meeting audio writer and start capture. See [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L87), [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L97), [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L116), [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L135), and [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L150).

### Live Processing

`Observed in code`: the meeting path normalizes everything to `16 kHz` mono. `Constants.sampleRate` is `16000`, `MeetingCoordinator.targetFormat` is mono Float32 at that rate, `SystemAudioCaptureManager` requests the same rate and one channel from `SCStreamConfiguration`, and `MeetingAudioWriter` writes a mono Float32 WAV at the same rate. See [Constants.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Utilities/Constants.swift#L4), [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L45), [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L55), [SystemAudioCaptureManager.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/SystemAudioCaptureManager.swift#L18), and [MeetingAudioWriter.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Meeting/MeetingAudioWriter.swift#L5).

`Observed in code`: microphone audio and system audio are summed into a single mono waveform before ASR and diarization. `AudioTapProcessor.process(_:)` converts the mic tap to the target format, reads `frameLength` system samples from `SystemAudioCaptureManager`, adds the two sample arrays with `vDSP_vadd`, writes that mixed result to disk, and appends the same mixed samples into the chunk buffer. There is no separate `mic.wav` or `system.wav` artifact in the current path. See [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L405), [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L438), [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L445), [SystemAudioCaptureManager.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/SystemAudioCaptureManager.swift#L88), and [MeetingAudioWriter.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Meeting/MeetingAudioWriter.swift#L42).

`Observed in code`: live transcription runs on a timer every 30 seconds by draining the current buffer. `MeetingCoordinator` declares `chunkSizeInSamples` as about 30 seconds of audio, but the actual loop is timer-driven: `chunkTask` sleeps for 30 seconds and then calls `processCurrentChunk()`, which drains the entire buffer and sends it to `MeetingTranscriptionPipeline.processChunk`. The declared `chunkSizeInSamples` is not used in chunk scheduling or slicing. See [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L45), [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L227), [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L510), and [MeetingTranscriptionPipeline.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Meeting/MeetingTranscriptionPipeline.swift#L29).

`Observed in code`: the live chunk pipeline is `ASR -> live diarization -> token/speaker merge`. `MeetingTranscriptionPipeline.processChunk` transcribes the mixed samples with `asrManager.transcribe(samples, source: .microphone)`, runs `diarizerManager.performCompleteDiarization(...)`, and then merges token timings to diarization segments with `mergeTimingsWithSpeakers`. See [MeetingTranscriptionPipeline.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Meeting/MeetingTranscriptionPipeline.swift#L29), [MeetingTranscriptionPipeline.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Meeting/MeetingTranscriptionPipeline.swift#L45), and [MeetingTranscriptionPipeline.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Meeting/MeetingTranscriptionPipeline.swift#L97).

### Stop

`Observed in code`: when the user stops a meeting, `MeetingCoordinator.stopMeeting()` cancels the timer tasks, processes the remaining chunk buffer, stops system audio capture, stops the audio engine, finalizes the mixed WAV, and then starts a second pass for "polish." That second pass runs `offlineDiarizer.process(audioURL)` on the full saved file, retranscribes the full file through the meeting `AsrManager`, and re-merges token timings against the offline speaker segments. See [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L239), [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L261), [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L266), and [MeetingTranscriptionPipeline.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Meeting/MeetingTranscriptionPipeline.swift#L97).

### Save

`Observed in code`: after the final offline re-attribution step, the app computes the unique speaker count from `liveSegments` and saves a `MeetingRecord` plus one `MeetingSegment` row per attributed segment into SwiftData. It also stores the relative path to the finalized WAV so the record knows where the audio artifact lives on disk. See [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L293), [MeetingService.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Meeting/MeetingService.swift#L24), [MeetingService.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Meeting/MeetingService.swift#L42), and [MeetingRecord.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Models/MeetingRecord.swift#L4).

### Playback And Review

`Observed in code`: the current meeting detail path is transcript review, not real audio playback UI. `MeetingsView` routes selection into `MeetingDetailView`, and `MeetingDetailView` lets the user edit the title, rename speakers inline, and copy the transcript. `MeetingRecord` exposes `audioFileURL`, so the audio artifact is persisted, but this view does not render player controls. In practice, "playback" in the current app means opening the saved transcript view and editing speaker display names after the fact. See [MeetingsView.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/UI/Pages/MeetingsView.swift#L13), [MeetingDetailView.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/UI/Pages/MeetingDetailView.swift#L16), [MeetingDetailView.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/UI/Pages/MeetingDetailView.swift#L174), and [MeetingRecord.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Models/MeetingRecord.swift#L46).

## Permission Flow

```mermaid
flowchart TD
    A[App launch] --> B[AppCoordinator.checkAll()]
    B --> C{allGranted?}
    C -->|No| D[OnboardingFlow]
    C -->|Yes| E[MainWindowView]

    D --> F[Accessibility]
    D --> G[Microphone]
    D --> H[Input Monitoring]
    D --> I[Screen Recording shown in separate Meetings section]

    F --> J[permissionManager.allGranted]
    G --> J
    H --> J
    I --> K[Not part of allGranted]

    E --> L[MeetingsView.task]
    L --> M[checkScreenRecording()]
    M --> N[CGPreflightScreenCaptureAccess fast path]
    M --> O[SCShareableContent async fallback]

    E --> P[User taps Start Meeting]
    P --> Q[MeetingCoordinator.startMeeting()]
    Q --> R[checkMicrophone()]
    Q --> S[Direct SCShareableContent gate]
    S -->|Fail| T[Meeting blocked with error]
    S -->|Pass| U[Meeting capture starts]
```

`Observed in code`: onboarding blocks only on Accessibility, Microphone, and Input Monitoring because `PermissionManager.allGranted` excludes Screen Recording. `thinkurApp` uses `permissionManager.allGranted` in the root gate, and `OnboardingViewModel.allPermissionsGranted` simply forwards the same property. See [PermissionManager.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/PermissionManager.swift#L8), [PermissionManager.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/PermissionManager.swift#L14), [thinkurApp.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/thinkurApp.swift#L48), and [OnboardingViewModel.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/ViewModels/OnboardingViewModel.swift#L104).

`Observed in code`: screen recording is meeting-specific and is enforced at meeting start, not as part of onboarding completion. `PermissionsView` renders Screen Recording in a separate "Meetings" section, `MeetingsView` checks it when entering the tab, and `MeetingCoordinator.startMeeting()` re-checks ScreenCaptureKit access directly before starting capture. See [PermissionsView.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/UI/Pages/PermissionsView.swift#L52), [MeetingsView.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/UI/Pages/MeetingsView.swift#L11), [MeetingsView.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/UI/Pages/MeetingsView.swift#L22), and [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L97).

`Observed in code`: `checkScreenRecording()` uses a fast preflight plus async `SCShareableContent` fallback because macOS Sequoia can misreport. The implementation first tries `CGPreflightScreenCaptureAccess()`, then, if that fails, runs an async `SCShareableContent.excludingDesktopWindows(...)` probe and updates `screenRecordingGranted` from the result. See [PermissionManager.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/PermissionManager.swift#L98).

`Observed in code`: debug builds reset TCC entries for `Microphone`, `Accessibility`, `ListenEvent`, `SpeechRecognition`, and `ScreenCapture`. This happens in the `thinkur` scheme post-action in `project.yml`. See [project.yml](/Users/jyo/Downloads/thinkur/project.yml#L68).

`Observed in code`: there is no special entitlement for screen capture here beyond runtime permission flow. The app entitlement file only declares `com.apple.security.device.audio-input`; there is no screen-capture-specific entitlement in this project. The app also carries standard microphone and speech usage strings in `Info.plist`. See [thinkur.entitlements](/Users/jyo/Downloads/thinkur/Sources/thinkur/Resources/thinkur.entitlements#L1) and [Info.plist](/Users/jyo/Downloads/thinkur/Sources/thinkur/Resources/Info.plist#L29).

## What The Current Stack Actually Is

| Layer | What the app is actually using | Evidence | Notes |
| --- | --- | --- | --- |
| Meeting ASR | `Parakeet v3` through a dedicated meeting `AsrManager` | [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L150), [AsrModels.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/ASR/AsrModels.swift#L5), [AsrModels.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/ASR/AsrModels.swift#L109), [ModelNames.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/ModelNames.swift#L141) | `MeetingCoordinator` explicitly downloads and loads `version: .v3`. |
| Live diarization | pyannote segmentation + WeSpeaker embedding style pipeline with in-memory `SpeakerManager` | [ModelNames.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/ModelNames.swift#L102), [DiarizerManager.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/Diarizer/Core/DiarizerManager.swift#L21), [DiarizerManager.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/Diarizer/Core/DiarizerManager.swift#L110), [SpeakerManager.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/Diarizer/Clustering/SpeakerManager.swift#L118) | Model names are `pyannote_segmentation` and `wespeaker_v2`, and IDs come from `SpeakerManager`. |
| Offline diarization | pyannote-community-style offline segmentation/embedding path with VBx clustering | [OfflineDiarizerTypes.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/Diarizer/Offline/Core/OfflineDiarizerTypes.swift#L30), [OfflineDiarizerManager.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/Diarizer/Offline/Core/OfflineDiarizerManager.swift#L116), [OfflineDiarizerManager.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/Diarizer/Offline/Core/OfflineDiarizerManager.swift#L224), [OfflineReconstruction.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/Diarizer/Offline/Utils/OfflineReconstruction.swift#L322) | Config comments explicitly say it is tuned to `community-1`, and clustering is AHC warm start plus VBx refinement. |
| Sortformer availability | FluidAudio ships a streaming Sortformer diarizer path | [SortformerDiarizerPipeline.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/Diarizer/Sortformer/SortformerDiarizerPipeline.swift#L6), [SortformerTypes.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/Diarizer/Sortformer/SortformerTypes.swift#L5), [ModelNames.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/ModelNames.swift#L216) | This is present in the dependency, with fixed speaker slots and streaming state. |
| Benchmarking and datasets | FluidAudio already contains benchmark commands and AMI dataset parsing | [DiarizationBenchmark.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudioCLI/Commands/DiarizationBenchmark.swift#L36), [SortformerBenchmark.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudioCLI/Commands/SortformerBenchmark.swift#L31), [AMIParser.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudioCLI/DatasetParsers/AMIParser.swift#L63) | The dependency can already benchmark DER/JER, but the app layer does not expose a product evaluation loop. |

`Inference`: FluidAudio also ships a Sortformer streaming diarizer path, but the app does not use it today. The app-layer meeting code instantiates `DiarizerManager`, `OfflineDiarizerManager`, and `AsrManager`; it does not instantiate a Sortformer pipeline in the meeting path. See [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L116), [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L135), [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L150), and [SortformerDiarizerPipeline.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/Diarizer/Sortformer/SortformerDiarizerPipeline.swift#L6).

## Why Speaker Labels Are Unstable Today

1. Mixing mic and system audio into one mono waveform destroys an easy source boundary and makes overlap handling harder.
   Label: `Observed in code`
   Evidence: the current meeting path sums microphone samples and system samples with `vDSP_vadd` before writing or diarizing, so the pipeline never sees separate tracks. See [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L438), [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L445), and [SystemAudioCaptureManager.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/SystemAudioCaptureManager.swift#L88).
   Inference: for 1:1 calls, this throws away the simplest speaker signal available: local mic versus remote/system source. For group calls, it also forces overlap resolution to happen inside one mixed waveform instead of one known track plus one unknown track.
   External research: WhisperX explicitly points meeting-transcription users toward separate audio streams from the meeting software as an alternative to pure diarization on mixed audio: <https://github.com/m-bain/whisperX>.

2. The app uses two different diarization systems for one meeting: live streaming-ish chunk attribution and final offline re-attribution.
   Label: `Observed in code`
   Evidence: live chunks go through `MeetingTranscriptionPipeline` with `DiarizerManager.performCompleteDiarization(...)`, but the final polish step runs `OfflineDiarizerManager.process(audioURL)` on the saved WAV and then replaces `liveSegments` using a second merge pass. See [MeetingTranscriptionPipeline.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Meeting/MeetingTranscriptionPipeline.swift#L45), [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L169), and [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L266).
   Inference: even if each individual stage is reasonable, the product-level label identity can drift because the "live speaker map" and the "final speaker map" are not the same system.

3. The "30 second chunking" is timer-based drain processing, and the declared `chunkSizeInSamples` is unused.
   Label: `Observed in code`
   Evidence: `chunkTask` sleeps for 30 seconds and drains the whole chunk buffer; the `chunkSizeInSamples` property is only declared, not used to control chunk boundaries. See [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L45), [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L227), and [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L510).
   Inference: this makes boundary behavior dependent on timer cadence and stop timing rather than an explicit streaming window policy, which is a poor foundation for stable speaker identity across long meetings.

4. Live IDs come from `SpeakerManager` as numeric IDs, while offline reconstruction emits `S1`, `S2`, and so on; the labeling scheme itself changes after stop.
   Label: `Observed in code`
   Evidence: `SpeakerManager.createNewSpeaker` emits stringified numeric IDs like `"1"` and `"2"`, while `OfflineReconstruction.appendSegment` emits `"S\(cluster + 1)"`. See [SpeakerManager.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/Diarizer/Clustering/SpeakerManager.swift#L477) and [OfflineReconstruction.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/Diarizer/Offline/Utils/OfflineReconstruction.swift#L322).
   Inference: even if the underlying speaker grouping were similar, the app still changes the user-visible label namespace when the meeting ends.

5. Token-to-speaker attribution is a simple overlap/midpoint mapping with no confidence-based reconciliation.
   Label: `Observed in code`
   Evidence: `mergeTimingsWithSpeakers` finds the overlapping diarization segment with the highest overlap, falls back to midpoint proximity, and groups consecutive tokens by speaker. There is no confidence score fusion, no overlap-aware multi-speaker token handling, and no identity reconciliation across the live/final swap. See [MeetingTranscriptionPipeline.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Meeting/MeetingTranscriptionPipeline.swift#L97).
   Inference: this makes attribution brittle around interruptions, overlap, short backchannels, and diarization boundary jitter.

6. The current pipeline has no meeting-specific regression harness in the app, so quality is not measurable from this repo alone.
   Label: `Inference`
   Evidence: the app-layer meeting path goes from `MeetingCoordinator` to `MeetingService` and UI views, but the quality tooling that exists today lives down in the FluidAudio CLI benchmark commands and dataset parsers. See [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L239), [MeetingService.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Meeting/MeetingService.swift#L24), [DiarizationBenchmark.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudioCLI/Commands/DiarizationBenchmark.swift#L36), and [AMIParser.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudioCLI/DatasetParsers/AMIParser.swift#L63).
   Inference: without a product-facing DER/WER harness around meetings, it is difficult to tell whether a model change, chunking change, or capture change actually improved speaker stability.

## Why Transcript Accuracy Suffers

`Observed in code`: current live meeting ASR runs on large drained chunks, then the final pass retranscribes the entire file. `MeetingTranscriptionPipeline` transcribes each mixed chunk during the meeting, and `stopMeeting()` later retranscribes the saved WAV from scratch before reassigning speakers. See [MeetingTranscriptionPipeline.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Meeting/MeetingTranscriptionPipeline.swift#L32) and [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L271).

`Observed in code`: the dependency supports vocabulary boosting and CTC rescoring, but the app does not configure it anywhere in the meeting or dictation layer. `AsrManager` exposes `configureVocabularyBoosting(...)`, `disableVocabularyBoosting()`, and the associated state, but the app-side source tree does not call those APIs. See [AsrManager.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/ASR/AsrManager.swift#L118).

`Inference`: for final-only mode, one full-file transcription pass plus one word-speaker assignment pass is cleaner than incremental live chunk transcription plus later replacement. It reduces duplicate decoding work, removes transcript churn, and gives diarization one stable timeline to align against.

`Inference`: dual-track capture is likely a bigger transcript-quality win than swapping Parakeet immediately, because each track becomes acoustically simpler. A clean local mic track and a clean remote/system track each present a narrower acoustic problem than a single mixed call recording.

## Recommended Simplification Path

### Recommendation A: Default Path

- Drop live speaker labeling entirely for meetings, or demote it to `draft only`.
- Record `mic.wav` and `system.wav` separately, plus optional `mixed.wav` only for debugging.
- For 1:1 calls, label local mic as one speaker and system audio as the other speaker directly.
- For group calls, diarize only the remote/system track and keep the local track as a fixed known speaker.
- Run final ASR and final diarization after stop, then merge by timestamps once.

Why this is the default recommendation:

- `Observed in code`: the current failure starts at capture, because the app throws away source separation before inference even begins. See [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L438).
- `Inference`: for 1:1 calls, separate tracks almost solve speaker attribution by construction.
- `Inference`: for group calls, keeping the local speaker fixed and diarizing only the remote track is still much easier than diarizing one fully mixed waveform.
- `External research`: pyannote and WhisperX both fit better as final-stage attribution tools than as justification for keeping the current mixed-live architecture. See <https://docs.pyannote.ai/features#speaker-diarization> and <https://github.com/m-bain/whisperX>.

### Recommendation B

- If dual-track capture is not possible, still collapse to one final-only full-file pipeline and remove the 30-second live chunk path.

Why this is the fallback:

- `Observed in code`: the current timer-based chunk drain plus later offline overwrite is adding product complexity without protecting either of the two objective functions. See [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L227) and [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L266).

### Recommendation C

- If live labels ever come back, test Sortformer from the existing dependency before introducing a brand new stack.

Why this is the tertiary path:

- `Observed in code`: the repo already contains a Sortformer implementation and benchmark harness, while the current app does not use it yet. See [SortformerDiarizerPipeline.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/Diarizer/Sortformer/SortformerDiarizerPipeline.swift#L6) and [SortformerBenchmark.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudioCLI/Commands/SortformerBenchmark.swift#L31).
- `Inference`: if you ever need draft labels again, the lowest-risk experiment is the model stack you already vendor, benchmark, and can run on-device.

### Future Interface Candidates

Documentation-only proposals for the next implementation cycle:

- `MeetingCaptureArtifacts { micURL, systemURL, mixedURL?, startedAt, duration }`
- `MeetingProcessingMode { finalOnly, liveDraft }`
- `SpeakerSource { localMic, remoteTrack, diarizedRemote(id) }`
- `SpeakerAttributedWord { token, startTime, endTime, speakerId, sourceTrack }`
- `MeetingProcessingResult { transcript, segments, speakers, diagnostics }`

### Concrete Implementation Plan

Implementation goal: move meetings from `one mixed live pipeline` to `two aligned recorded tracks + one final attribution pass`.

#### Phase 1: Split Capture Without Changing Permissions

- `Observed in code`: the app already has two inputs available at meeting time: mic audio from the AVAudioEngine tap and system audio from `SystemAudioCaptureManager`. The current code reads both, then sums them. See [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L339), [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L438), and [SystemAudioCaptureManager.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/SystemAudioCaptureManager.swift#L88).
- Change the capture path so the mic callback remains the master clock, but instead of `vDSP_vadd` into one array:
  - write converted mic samples to `mic.wav`
  - read same-length system samples from the ring buffer and write them to `system.wav`
  - optionally create `mixed.wav` only in debug builds or behind a diagnostics flag
- `Inference`: using the mic callback as the shared clock preserves the alignment behavior the current code already approximates, because `readSamples(count:)` already zero-pads under-runs and returns a timeline-compatible array.
- File touchpoints:
  - [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L385)
  - [SystemAudioCaptureManager.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/SystemAudioCaptureManager.swift#L84)
  - [MeetingAudioWriter.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Meeting/MeetingAudioWriter.swift#L42)
- Concrete implementation shape:
  - replace the single `MeetingAudioWriter` with either:
    - one small wrapper that owns three writers: `mic`, `system`, `mixed?`
    - or a generalized `MeetingTrackWriter(trackName:)`
  - keep sample rate and channel count exactly as they are now: `16 kHz`, mono, Float32. See [Constants.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Utilities/Constants.swift#L4) and [MeetingAudioWriter.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Meeting/MeetingAudioWriter.swift#L22).

#### Phase 2: Remove Live Chunk Attribution From The Critical Path

- `Observed in code`: today the meeting path spins a 30-second timer and drains the buffer into `MeetingTranscriptionPipeline`, then later overwrites the result with an offline pass. See [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L227), [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L510), and [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L266).
- Default change:
  - do not create or run `chunkTask` for meetings in `finalOnly` mode
  - do not update `liveSegments` with draft speaker labels while recording
  - keep only recording status, elapsed time, and audio level live in the UI
- `Inference`: if the only thing that matters is final speaker labels plus final transcript accuracy, every minute spent stabilizing live chunk attribution is a distraction.
- File touchpoints:
  - [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L169)
  - [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L227)
  - [MeetingsView.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/UI/Pages/MeetingsView.swift#L10)

#### Phase 3: Final-Only Processing Pipeline

- For `1:1` calls:
  - run ASR on `mic.wav`
  - run ASR on `system.wav`
  - assign all `mic.wav` words to a fixed local speaker, for example `Speaker 1`
  - assign all `system.wav` words to a fixed remote speaker, for example `Speaker 2`
  - merge the two timed word streams into one final transcript
- For `group` calls:
  - run ASR on `mic.wav`
  - run ASR on `system.wav`
  - assign all `mic.wav` words to a fixed local speaker
  - run offline diarization only on `system.wav`
  - merge remote ASR token timings with remote diarization segments
  - merge local words and remote attributed words into one final time-ordered transcript
- `Inference`: this is the cleanest way to turn "speaker identity" into a data problem instead of a clustering problem. The local track is known by construction.
- File touchpoints:
  - [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L266)
  - [MeetingTranscriptionPipeline.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Meeting/MeetingTranscriptionPipeline.swift#L97)
  - [OfflineDiarizerManager.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/Diarizer/Offline/Core/OfflineDiarizerManager.swift#L209)
  - [AsrManager.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/ASR/AsrManager.swift#L118)

Recommended processing order:

1. Finalize `mic.wav` and `system.wav`.
2. Transcribe both tracks independently.
3. If remote track is multi-speaker, diarize only `system.wav`.
4. Convert words into `SpeakerAttributedWord { token, startTime, endTime, speakerId, sourceTrack }`.
5. Merge once into final segments and persist.

#### Phase 4: Stabilize Speaker Identity Rules

- Assign one permanent ID to the local track for the entire meeting.
- Never reuse the current live numeric `SpeakerManager` IDs for final meeting storage.
- Normalize final remote labels into one namespace only, for example:
  - `L1` for local mic
  - `R1`, `R2`, `R3` for diarized remote speakers
- `Observed in code`: current live and offline paths use different naming schemes today. See [SpeakerManager.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/Diarizer/Clustering/SpeakerManager.swift#L477) and [OfflineReconstruction.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/Diarizer/Offline/Utils/OfflineReconstruction.swift#L343).
- `Inference`: a stable label namespace is a product requirement, not just an inference detail.

#### Phase 5: Persist Better Meeting Artifacts

- Extend meeting persistence so each meeting knows:
  - `micURL`
  - `systemURL`
  - optional `mixedURL`
  - processing mode
  - diagnostics such as whether remote diarization ran
- `Observed in code`: the current `MeetingRecord` only stores one `audioFileRelativePath`. See [MeetingRecord.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Models/MeetingRecord.swift#L6).
- `Inference`: you do not need to expose all artifact paths in the UI immediately, but you should persist them before iterating on model quality so experiments are reproducible.
- File touchpoints:
  - [MeetingRecord.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Models/MeetingRecord.swift#L4)
  - [MeetingService.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Meeting/MeetingService.swift#L24)

#### Phase 6: UI Simplification

- During recording, show:
  - recording state
  - elapsed time
  - input level
  - maybe a single line saying `Final transcript will be generated when the meeting ends`
- Do not show draft speaker labels in the primary experience.
- In the saved meeting view, keep:
  - title editing
  - speaker renaming
  - transcript copy
- `Observed in code`: the current detail view is already transcript-first and supports speaker renaming after the fact, which fits the final-only model well. See [MeetingDetailView.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/UI/Pages/MeetingDetailView.swift#L174).

#### Phase 7: Evaluation Before Model Swaps

- Before changing diarization models, build one repeatable meeting-quality harness around the new dual-track pipeline.
- Minimum gating tests:
  - 1:1 local vs remote call
  - 3+ person remote group call
  - overlap where local interrupts remote
  - long silence and speaker re-entry
  - proper nouns
- Success criteria for shipping the simplified architecture:
  - 1:1 meetings do not require diarization at all
  - local speaker label never changes within a meeting
  - remote speaker labels do not renumber between save and reopen
  - final transcript quality is measurably better than the current mixed pipeline on the same recordings

#### Recommended Build Order

1. Split recording into `mic.wav` and `system.wav` while keeping current permissions and UI behavior.
2. Disable the 30-second meeting chunk pipeline behind a `finalOnly` processing mode.
3. Transcribe both tracks separately and merge them by timestamps.
4. For 1:1 meetings, skip diarization entirely.
5. For group calls, diarize only `system.wav`.
6. Add artifact persistence and diagnostics.
7. Add the evaluation harness.
8. Only then compare pyannote Community-1 versus the current FluidAudio offline VBx path.

#### Non-Goals For The First Pass

- Do not try to preserve live speaker labels.
- Do not add more complex chunking.
- Do not replace Parakeet first.
- Do not add a new diarization stack until the capture architecture is fixed.

## Open-Source Research Matrix

| Option | Type | Strengths | Weaknesses | Best fit for thinkur | Research priority |
| --- | --- | --- | --- | --- | --- |
| [`pyannote Community-1`](https://docs.pyannote.ai/features#speaker-diarization) | Offline diarization pipeline | Mature speaker-count controls, `exclusive diarization`, strong community baseline, clear final-pass semantics | Python-centric integration path, needs Apple Silicon benchmarking for your exact capture setup | Best external final-attribution benchmark target against the current stack | Highest |
| `FluidAudio current offline VBx path` | Current on-device offline diarizer | Already integrated in the meeting stop path and benchmark tooling exists. See [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L266), [OfflineDiarizerManager.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/Diarizer/Offline/Core/OfflineDiarizerManager.swift#L209), and [DiarizationBenchmark.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudioCLI/Commands/DiarizationBenchmark.swift#L36). | Still fed by mixed audio today, app layer lacks product evaluation loop, label namespace changes on stop. See [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L438), [OfflineReconstruction.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/Diarizer/Offline/Utils/OfflineReconstruction.swift#L322), and [MeetingService.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Meeting/MeetingService.swift#L24). | Baseline to beat before adopting a new stack | High |
| [`FluidAudio / NeMo Sortformer`](https://docs.nvidia.com/nemo-framework/user-guide/latest/nemotoolkit/asr/speaker_diarization/models.html) | Streaming diarizer | Already vendored and benchmarked in the dependency, real-time-oriented. See [SortformerDiarizerPipeline.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/Diarizer/Sortformer/SortformerDiarizerPipeline.swift#L6) and [SortformerBenchmark.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudioCLI/Commands/SortformerBenchmark.swift#L31). | Live-first, fixed speaker-slot assumptions, less aligned with a final-only quality goal | Draft/live label fallback if live labels return | Medium, live-label fallback |
| [`WhisperX + pyannote`](https://github.com/m-bain/whisperX) | ASR + alignment + diarization research stack | Good ecosystem reference for word timing and diarization composition; explicitly points to separate-stream alternatives for meetings | Usually Python-heavy, often GPU-biased, not a drop-in on-device Swift solution | Comparative research reference, not the first implementation path | Medium |
| [`Platform / separate-stream architectures`](https://github.com/m-bain/whisperX) | Capture architecture | Highest leverage for both objective functions, especially 1:1 calls; can avoid diarization for the local speaker entirely | Requires capture redesign and possibly platform-specific integrations or metadata | Best structural fit for thinkur if final accuracy matters more than live UX | Highest |

## External Sources To Hand To The Deep-Research Agent

- Pyannote diarization docs: <https://docs.pyannote.ai/features#speaker-diarization>
- Pyannote project repo: <https://github.com/pyannote/pyannote-audio>
- NVIDIA Sortformer model card: <https://huggingface.co/nvidia/streaming-sortformer-diarizer>
- NVIDIA NeMo diarization docs: <https://docs.nvidia.com/nemo-framework/user-guide/latest/nemotoolkit/asr/speaker_diarization/models.html>
- WhisperX project repo: <https://github.com/m-bain/whisperX>
- WhisperX paper: <https://arxiv.org/abs/2303.00747>

`External research`: pyannote exposes `num_speakers`, `min_speakers`, `max_speakers`, and `exclusive diarization`. Those controls make it a good benchmark target for a final-only meeting pipeline, especially if you want to compare fixed-speaker-count 1:1 calls versus looser group-call settings. Source: <https://docs.pyannote.ai/features#speaker-diarization>.

`External research`: WhisperX explicitly points users doing meeting transcription toward participant-separated audio streams from the meeting platform as an alternative to pure diarization on mixed audio. That is directly aligned with the strongest architectural improvement suggested by the current code review. Source: <https://github.com/m-bain/whisperX>.

## Questions For The Downstream Research Agent

1. Which open-source diarization stack gives the best final speaker labeling on dual-track video-call audio on Apple Silicon?
2. For mixed group calls, is it better to diarize only the remote track or to attempt joint diarization on a recombined mix?
3. Is pyannote Community-1 materially better than the current FluidAudio offline VBx path on AMI, CALLHOME, and VoxConverse?
4. Is FluidAudio Sortformer mature enough to use as a draft/live labeler while keeping final attribution offline?
5. Which open-source meeting transcription apps or meeting bots avoid diarization by using participant-separated audio, platform metadata, or both?
6. Which ASR alternatives are worth comparing to Parakeet for final meeting transcription on-device, and under what hardware/latency constraints?

## Evaluation Plan

### Public-Benchmark Track

- Use the existing benchmark-oriented dependency surface as the baseline harness: compare the current FluidAudio offline VBx path, pyannote Community-1, and Sortformer where relevant. See [DiarizationBenchmark.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudioCLI/Commands/DiarizationBenchmark.swift#L36), [SortformerBenchmark.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudioCLI/Commands/SortformerBenchmark.swift#L31), and [AMIParser.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudioCLI/DatasetParsers/AMIParser.swift#L63).
- Run AMI, CALLHOME, and VoxConverse comparisons where possible, because they stress different speaker-count and overlap regimes.
- Keep one comparison axis fixed: mixed single-track input versus separated local/remote tracks, because that is the architectural question most likely to dominate results.

### Product-Benchmark Track

Required scenarios:

- `1:1 video call with one local and one remote speaker`
- `3+ person group call with overlapping remote speakers`
- `Local user interrupting a remote speaker`
- `Speaker leaves and rejoins after a long silence`
- `Audio device change mid-meeting`
- `Missing Screen Recording permission`
- `Meeting with domain-specific proper nouns`

Required metrics:

- `DER`
- `JER`
- `speaker fragmentation`
- `speaker-label stability across the meeting`
- `WER`
- `CER`
- a small manual `speaker identity consistency` rubric

Recommended manual rubric for `speaker identity consistency`:

- `0`: labels reset, split, or swap often enough that the transcript is not trustworthy.
- `1`: mostly usable, but one or two obvious label resets or merges happen.
- `2`: stable enough that a human can read the transcript without mentally relabeling speakers.

Product-specific checks to add:

- Verify that missing Screen Recording permission blocks meeting start clearly and consistently.
- Verify that audio device changes do not silently corrupt track identity or reset diarization state without notice.
- Measure final-only output separately from any optional live draft output so the two objective functions do not get conflated with UX latency.

## Appendix: Exact Local Sources

- [thinkurApp.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/thinkurApp.swift#L39)
- [PermissionManager.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/PermissionManager.swift#L18)
- [MeetingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/MeetingCoordinator.swift#L87)
- [MeetingTranscriptionPipeline.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Meeting/MeetingTranscriptionPipeline.swift#L29)
- [SystemAudioCaptureManager.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/SystemAudioCaptureManager.swift#L22)
- [MeetingService.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Meeting/MeetingService.swift#L24)
- [RecordingCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Coordinators/RecordingCoordinator.swift#L84)
- [DiarizerManager.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/Diarizer/Core/DiarizerManager.swift#L110)
- [SpeakerManager.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/Diarizer/Clustering/SpeakerManager.swift#L118)
- [OfflineDiarizerManager.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/Diarizer/Offline/Core/OfflineDiarizerManager.swift#L209)
- [OfflineReconstruction.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/Diarizer/Offline/Utils/OfflineReconstruction.swift#L322)
- [SortformerDiarizerPipeline.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/Diarizer/Sortformer/SortformerDiarizerPipeline.swift#L6)
- [AsrManager.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/ASR/AsrManager.swift#L118)
- [DiarizationBenchmark.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudioCLI/Commands/DiarizationBenchmark.swift#L36)
- [SortformerBenchmark.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudioCLI/Commands/SortformerBenchmark.swift#L31)
- [AMIParser.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudioCLI/DatasetParsers/AMIParser.swift#L63)

Additional supporting references used in this brief:

- [AppCoordinator.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/AppCoordinator.swift#L42)
- [MeetingsView.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/UI/Pages/MeetingsView.swift#L19)
- [MeetingDetailView.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/UI/Pages/MeetingDetailView.swift#L156)
- [OnboardingViewModel.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/ViewModels/OnboardingViewModel.swift#L104)
- [PermissionsView.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/UI/Pages/PermissionsView.swift#L1)
- [project.yml](/Users/jyo/Downloads/thinkur/project.yml#L75)
- [thinkur.entitlements](/Users/jyo/Downloads/thinkur/Sources/thinkur/Resources/thinkur.entitlements#L1)
- [Info.plist](/Users/jyo/Downloads/thinkur/Sources/thinkur/Resources/Info.plist#L29)
- [ViewModelFactory.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/DI/ViewModelFactory.swift#L45)
- [MeetingAudioWriter.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Core/Meeting/MeetingAudioWriter.swift#L5)
- [MeetingRecord.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Models/MeetingRecord.swift#L48)
- [Constants.swift](/Users/jyo/Downloads/thinkur/Sources/thinkur/Utilities/Constants.swift#L4)
- [OfflineDiarizerTypes.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/Diarizer/Offline/Core/OfflineDiarizerTypes.swift#L30)
- [AsrModels.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/ASR/AsrModels.swift#L5)
- [ModelNames.swift](/Users/jyo/Downloads/thinkur/.build/checkouts/FluidAudio/Sources/FluidAudio/ModelNames.swift#L102)
