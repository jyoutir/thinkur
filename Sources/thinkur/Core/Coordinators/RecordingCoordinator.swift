import Cocoa
import os

@MainActor
@Observable
final class RecordingCoordinator {
    var state: AppState = .idle

    private let audioCaptureManager: any AudioCapturing
    private let transcriptionEngine: any Transcribing
    private let textInsertionService: any TextInserting
    private let textPostProcessor: TextPostProcessor
    private let postProcessingActor: PostProcessingActor
    private let frontmostAppDetector: FrontmostAppDetector
    private let analyticsService: any AnalyticsRecording
    private let shortcutService: any ShortcutLookup
    private let smartHomeService: SmartHomeService?
    private let amplitudeProvider: AudioAmplitudeProvider
    private let stylePreferenceService: StylePreferenceService
    private let settings: SettingsManager
    private let sharedState: SharedAppState
    private var floatingPanel: FloatingIndicatorPanel?
    private var notchPanels: NotchIndicatorPanels?

    init(
        audioCaptureManager: any AudioCapturing,
        transcriptionEngine: any Transcribing,
        textInsertionService: any TextInserting,
        textPostProcessor: TextPostProcessor,
        frontmostAppDetector: FrontmostAppDetector,
        analyticsService: any AnalyticsRecording,
        amplitudeProvider: AudioAmplitudeProvider,
        settings: SettingsManager,
        sharedState: SharedAppState,
        shortcutService: any ShortcutLookup,
        stylePreferenceService: StylePreferenceService,
        smartHomeService: SmartHomeService? = nil,
        createFloatingPanel: Bool = true
    ) {
        self.audioCaptureManager = audioCaptureManager
        self.transcriptionEngine = transcriptionEngine
        self.textInsertionService = textInsertionService
        self.textPostProcessor = textPostProcessor
        self.postProcessingActor = PostProcessingActor(processor: textPostProcessor)
        self.frontmostAppDetector = frontmostAppDetector
        self.analyticsService = analyticsService
        self.shortcutService = shortcutService
        self.smartHomeService = smartHomeService
        self.amplitudeProvider = amplitudeProvider
        self.settings = settings
        self.sharedState = sharedState
        self.stylePreferenceService = stylePreferenceService
        if createFloatingPanel {
            self.floatingPanel = FloatingIndicatorPanel(amplitudeProvider: amplitudeProvider, themeMode: settings.themeMode)
            floatingPanel?.onTap = { [weak self] in
                self?.toggleListening()
            }
            let notch = NotchIndicatorPanels(amplitudeProvider: amplitudeProvider)
            notch.onLeftWingTapped = { [weak self] in
                self?.toggleListening()
            }
            self.notchPanels = notch
            notch.showLeftWing()
            // Show persistent bottom bar in idle state
            floatingPanel?.show()
        }
    }

    func toggleListening() {
        switch state {
        case .listening:
            Task { await stopAndTranscribe() }
        case .idle:
            startRecording()
        default:
            break
        }
    }

    func startRecording() {
        let previousState = state
        do {
            try audioCaptureManager.startCapture()
            updateState(.listening)

            if settings.soundEffects {
                let style = SoundStyle(rawValue: settings.soundStyle) ?? .chime
                ToneGenerator.shared.playStartTone(style: style)
            }
            if settings.dimMusicWhileRecording {
                MediaControlService.dimPlayback()
            }

            amplitudeProvider.startPolling { [weak self] in
                self?.audioCaptureManager.currentAudioLevel ?? 0
            }
            floatingPanel?.updateAppearance(for: settings.themeMode)
            floatingPanel?.show()  // Recenter and ensure visible
            Logger.app.info("Listening started")
        } catch {
            updateState(previousState)
            Logger.app.error("Failed to start audio capture: \(error)")
        }
    }

    func stopAndTranscribe() async {
        guard state == .listening else { return }

        if settings.soundEffects {
            let style = SoundStyle(rawValue: settings.soundStyle) ?? .chime
            ToneGenerator.shared.playStopTone(style: style)
        }
        if settings.dimMusicWhileRecording {
            MediaControlService.restorePlayback()
        }

        amplitudeProvider.stopPolling()
        floatingPanel?.setState(.processing)
        let samples = audioCaptureManager.stopCapture()
        updateState(.processing)

        let duration = Double(samples.count) / Constants.sampleRate
        guard duration >= 0.3 else {
            Logger.app.info("Recording too short (\(String(format: "%.1f", duration))s), skipping")
            updateState(.idle)
            return
        }

        let trimmedSamples = trimSilence(from: samples)

        if !transcriptionEngine.isLoaded {
            Logger.app.info("Waiting for model to finish loading...")
            while !transcriptionEngine.isLoaded && transcriptionEngine.isLoading {
                try? await Task.sleep(for: .milliseconds(200))
            }
        }

        if let rawText = await transcriptionEngine.transcribe(audioSamples: trimmedSamples) {
            let bundleID = frontmostAppDetector.bundleID
            let userStyleString = await stylePreferenceService.getStyle(for: bundleID)
            let resolvedStyle = userStyleString.flatMap { AppStyle(from: $0) }
                             ?? AppStyleMap.style(for: bundleID)
            let context = ProcessingContext(
                frontmostAppBundleID: bundleID,
                frontmostAppName: frontmostAppDetector.appName,
                wordTimings: transcriptionEngine.lastWordTimings,
                appStyle: resolvedStyle
            )
            let text: String
            let correctionCount: Int
            if settings.postProcessingEnabled {
                var disabled = Set<String>()
                if !settings.removeFillerWords { disabled.insert("FillerRemoval") }
                if !settings.autoPunctuation { disabled.insert("SpokenPunctuation"); disabled.insert("PausePunctuation") }
                if !settings.intentCorrection { disabled.insert("SelfCorrection") }
                if !settings.smartFormatting { disabled.insert("SmartFormatting") }
                if !settings.listFormatting { disabled.insert("ListDetection") }
                // Run post-processing on background actor to avoid blocking main thread (200-500ms typical)
                let result = await postProcessingActor.process(rawText, context: context, disabledProcessors: disabled)
                text = result.text
                correctionCount = result.corrections.count
            } else {
                text = rawText
                correctionCount = 0
            }
            // Check for smart home command (before shortcuts and text insertion)
            if let smartHome = smartHomeService,
               await smartHome.tryExecuteCommand(text: text) {
                sharedState.lastSmartHomeAction = smartHome.lastActionMessage
                sharedState.lastTranscription = text
                Logger.app.info("Smart home command executed, skipping text insertion")
                analyticsService.record(
                    rawText: rawText,
                    processedText: text,
                    duration: duration,
                    appBundleID: frontmostAppDetector.bundleID,
                    appName: frontmostAppDetector.appName,
                    correctionCount: correctionCount
                )
                sharedState.transcriptionVersion += 1
                updateState(.idle)
                return
            }

            // Apply shortcut expansions (inline find-and-replace)
            let finalText = await shortcutService.applyShortcuts(to: text)

            sharedState.lastTranscription = finalText
            textInsertionService.insertText(finalText)
            Logger.app.info("Inserted transcription (\(text.count) chars)")

            analyticsService.record(
                rawText: rawText,
                processedText: text,
                duration: duration,
                appBundleID: frontmostAppDetector.bundleID,
                appName: frontmostAppDetector.appName,
                correctionCount: correctionCount
            )
            sharedState.transcriptionVersion += 1
        } else {
            Logger.app.info("No transcription result")
        }

        updateState(.idle)
    }

    /// Trim leading/trailing silence using adaptive energy detection.
    /// Uses a relative threshold (10% of peak RMS) so it works regardless of mic gain.
    private func trimSilence(from samples: [Float]) -> [Float] {
        let frameSamples = Int(0.1 * Constants.sampleRate) // 100ms = 1600 samples
        let frameCount = (samples.count + frameSamples - 1) / frameSamples
        guard frameCount >= 3 else { return samples }

        // Compute RMS energy per frame
        var energies = [Float](repeating: 0, count: frameCount)
        for i in 0..<frameCount {
            let start = i * frameSamples
            let end = min(start + frameSamples, samples.count)
            var sumSq: Float = 0
            for j in start..<end {
                sumSq += samples[j] * samples[j]
            }
            energies[i] = sqrt(sumSq / Float(end - start))
        }

        // Adaptive threshold: 10% of peak energy — works with any mic gain
        let peakEnergy = energies.max() ?? 0
        guard peakEnergy > 1e-6 else { return samples }
        let threshold = peakEnergy * 0.1

        guard let firstActive = energies.firstIndex(where: { $0 > threshold }),
              let lastActive = energies.lastIndex(where: { $0 > threshold }) else {
            return samples
        }

        let paddingSamples = Int(0.15 * Constants.sampleRate) // 150ms padding
        let startSample = max(0, firstActive * frameSamples - paddingSamples)
        let endSample = min(samples.count, (lastActive + 1) * frameSamples + paddingSamples)

        // Only trim if we'd save at least 200ms
        guard samples.count - (endSample - startSample) > Int(0.2 * Constants.sampleRate) else {
            return samples
        }

        let trimmed = Array(samples[startSample..<endSample])
        let trimmedDuration = Double(trimmed.count) / Constants.sampleRate
        let originalDuration = Double(samples.count) / Constants.sampleRate
        Logger.app.info("Trimmed silence: \(String(format: "%.1f", originalDuration))s → \(String(format: "%.1f", trimmedDuration))s")

        return trimmed
    }

    private func updateState(_ newState: AppState) {
        state = newState
        sharedState.appState = newState
        let spinnerState = SpinnerState(from: newState)
        notchPanels?.setState(spinnerState)
        floatingPanel?.setState(spinnerState)
    }
}
