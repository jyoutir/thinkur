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
    private let frontmostAppDetector: FrontmostAppDetector
    private let analyticsService: any AnalyticsRecording
    private let shortcutService: any ShortcutLookup
    private let amplitudeProvider: AudioAmplitudeProvider
    private let settings: SettingsManager
    private let sharedState: SharedAppState
    private var floatingPanel: FloatingIndicatorPanel?

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
        createFloatingPanel: Bool = true
    ) {
        self.audioCaptureManager = audioCaptureManager
        self.transcriptionEngine = transcriptionEngine
        self.textInsertionService = textInsertionService
        self.textPostProcessor = textPostProcessor
        self.frontmostAppDetector = frontmostAppDetector
        self.analyticsService = analyticsService
        self.shortcutService = shortcutService
        self.amplitudeProvider = amplitudeProvider
        self.settings = settings
        self.sharedState = sharedState
        if createFloatingPanel {
            self.floatingPanel = FloatingIndicatorPanel(amplitudeProvider: amplitudeProvider)
        }
    }

    func startRecording() {
        let previousState = state
        do {
            try audioCaptureManager.startCapture()
            updateState(.listening)

            if settings.soundEffects {
                NSSound(named: "Tink")?.play()
            }
            if settings.pauseMusicWhileRecording {
                MediaControlService.pausePlayback()
            }

            amplitudeProvider.startPolling { [weak self] in
                self?.audioCaptureManager.currentAudioLevel ?? 0
            }
            if settings.floatingIndicator {
                floatingPanel?.show()
            }
            Logger.app.info("Listening started")
        } catch {
            updateState(previousState)
            Logger.app.error("Failed to start audio capture: \(error)")
        }
    }

    func stopAndTranscribe() async {
        guard state == .listening else { return }

        if settings.soundEffects {
            NSSound(named: "Pop")?.play()
        }
        if settings.pauseMusicWhileRecording {
            MediaControlService.resumePlayback()
        }

        amplitudeProvider.stopPolling()
        floatingPanel?.hideWithThinkingTransition()

        let samples = audioCaptureManager.stopCapture()
        updateState(.processing)

        let duration = Double(samples.count) / Constants.sampleRate
        guard duration >= 0.3 else {
            Logger.app.info("Recording too short (\(String(format: "%.1f", duration))s), skipping")
            updateState(.idle)
            return
        }

        if !transcriptionEngine.isLoaded {
            Logger.app.info("Waiting for model to finish loading...")
            while !transcriptionEngine.isLoaded && transcriptionEngine.isLoading {
                try? await Task.sleep(for: .milliseconds(200))
            }
        }

        if let rawText = await transcriptionEngine.transcribe(audioSamples: samples) {
            let context = ProcessingContext(
                frontmostAppBundleID: frontmostAppDetector.bundleID,
                frontmostAppName: frontmostAppDetector.appName,
                wordTimings: transcriptionEngine.lastWordTimings,
                appStyle: AppStyleMap.style(for: frontmostAppDetector.bundleID)
            )
            let text: String
            if settings.postProcessingEnabled {
                var disabled = Set<String>()
                if !settings.removeFillerWords { disabled.insert("FillerRemoval") }
                if !settings.autoPunctuation { disabled.insert("SpokenPunctuation"); disabled.insert("PausePunctuation") }
                if !settings.intentCorrection { disabled.insert("SelfCorrection") }
                if !settings.smartFormatting { disabled.insert("NumberConversion"); disabled.insert("Capitalization"); disabled.insert("StyleAdaptation") }
                text = textPostProcessor.process(rawText, context: context, disabledProcessors: disabled)
            } else {
                text = rawText
            }
            // Check for shortcut expansion
            var finalText = text
            if let expansion = await shortcutService.findExpansion(for: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                finalText = expansion
            }

            sharedState.lastTranscription = finalText
            textInsertionService.insertText(finalText)
            Logger.app.info("Inserted transcription: \"\(text)\"")

            Task {
                analyticsService.record(
                    rawText: rawText,
                    processedText: text,
                    duration: duration,
                    appBundleID: frontmostAppDetector.bundleID,
                    appName: frontmostAppDetector.appName
                )
            }
        } else {
            Logger.app.info("No transcription result")
        }

        updateState(.idle)
    }

    private func updateState(_ newState: AppState) {
        state = newState
        sharedState.appState = newState
    }
}
