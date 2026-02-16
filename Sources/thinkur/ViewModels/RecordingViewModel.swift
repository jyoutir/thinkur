import Cocoa
import os

@MainActor
@Observable
final class RecordingViewModel {
    var state: AppState = .idle

    var onStateChanged: ((AppState) -> Void)?
    var onTranscription: ((String) -> Void)?

    private let audioCaptureManager: any AudioCapturing
    private let transcriptionEngine: any Transcribing
    private let textInsertionService: any TextInserting
    private let textPostProcessor: TextPostProcessor
    private let frontmostAppDetector: FrontmostAppDetector
    private let analyticsService: AnalyticsService
    private let shortcutService: ShortcutService?
    private let amplitudeProvider: AudioAmplitudeProvider
    private let hotkeyManager: any HotkeyListening
    private let settings: SettingsManager
    private let sharedState: SharedAppState?
    private var floatingPanel: FloatingIndicatorPanel?

    init(
        audioCaptureManager: any AudioCapturing,
        transcriptionEngine: any Transcribing,
        textInsertionService: any TextInserting,
        textPostProcessor: TextPostProcessor,
        frontmostAppDetector: FrontmostAppDetector,
        analyticsService: AnalyticsService,
        amplitudeProvider: AudioAmplitudeProvider,
        hotkeyManager: any HotkeyListening,
        settings: SettingsManager = .shared,
        sharedState: SharedAppState? = nil,
        shortcutService: ShortcutService? = nil,
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
        self.hotkeyManager = hotkeyManager
        self.settings = settings
        self.sharedState = sharedState
        if createFloatingPanel {
            self.floatingPanel = FloatingIndicatorPanel(amplitudeProvider: amplitudeProvider)
        }
    }

    var isModelReady: Bool {
        get { sharedState?.isModelReady ?? false }
        set { sharedState?.isModelReady = newValue }
    }

    func setupHotkey() {
        hotkeyManager.onKeyDown = { [weak self] in
            Task { @MainActor in
                self?.handleKeyDown()
            }
        }
        hotkeyManager.onKeyUp = { [weak self] in
            Task { @MainActor in
                self?.handleKeyUp()
            }
        }

        let success = hotkeyManager.start()
        if !success {
            Logger.app.warning("Hotkey manager failed to start — will retry in 3s")
            Task {
                for attempt in 1...5 {
                    try? await Task.sleep(for: .seconds(3))
                    Logger.app.info("Retrying hotkey setup (attempt \(attempt)/5)")
                    if hotkeyManager.start() {
                        Logger.app.info("Hotkey manager started on retry \(attempt)")
                        return
                    }
                }
                Logger.app.error("Hotkey manager failed after 5 retries — grant Accessibility permission and restart thinkur")
            }
        }
    }

    private func handleKeyDown() {
        if settings.hotkeyHoldMode {
            // Hold mode: key down starts listening
            if state == .idle || state == .loading {
                startListening()
            }
        } else {
            // Toggle mode: key down toggles
            toggleListening()
        }
    }

    private func handleKeyUp() {
        if settings.hotkeyHoldMode && state == .listening {
            // Hold mode: key up stops listening
            Task {
                await stopListeningAndTranscribe()
            }
        }
    }

    private func toggleListening() {
        switch state {
        case .listening:
            Task {
                await stopListeningAndTranscribe()
            }
        case .idle, .loading:
            startListening()
        default:
            Logger.app.warning("Cannot toggle listening: state is \(String(describing: self.state))")
        }
    }

    private func startListening() {
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

    private func stopListeningAndTranscribe() async {
        guard state == .listening else { return }

        if settings.soundEffects {
            NSSound(named: "Pop")?.play()
        }
        if settings.pauseMusicWhileRecording {
            MediaControlService.resumePlayback()
        }

        amplitudeProvider.stopPolling()
        floatingPanel?.hide()

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
            if let shortcutService, let expansion = await shortcutService.findExpansion(for: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                finalText = expansion
            }

            onTranscription?(finalText)
            sharedState?.lastTranscription = finalText
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
        sharedState?.appState = newState
        onStateChanged?(newState)
    }
}
