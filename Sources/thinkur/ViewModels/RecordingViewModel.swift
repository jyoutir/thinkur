import Cocoa
import os

@MainActor
final class RecordingViewModel: ObservableObject {
    @Published var state: AppState = .idle
    var isModelReady = false

    var onStateChanged: ((AppState) -> Void)?
    var onTranscription: ((String) -> Void)?

    private let audioCaptureManager: AudioCaptureManager
    private let transcriptionEngine: TranscriptionEngine
    private let textInsertionService: TextInsertionService
    private let amplitudeProvider: AudioAmplitudeProvider
    private let hotkeyManager: HotkeyManager
    private var floatingPanel: FloatingIndicatorPanel?

    init(
        audioCaptureManager: AudioCaptureManager,
        transcriptionEngine: TranscriptionEngine,
        textInsertionService: TextInsertionService,
        amplitudeProvider: AudioAmplitudeProvider,
        hotkeyManager: HotkeyManager
    ) {
        self.audioCaptureManager = audioCaptureManager
        self.transcriptionEngine = transcriptionEngine
        self.textInsertionService = textInsertionService
        self.amplitudeProvider = amplitudeProvider
        self.hotkeyManager = hotkeyManager
        self.floatingPanel = FloatingIndicatorPanel(amplitudeProvider: amplitudeProvider)
    }

    func setupHotkey() {
        hotkeyManager.onKeyDown = { [weak self] in
            Task { @MainActor in
                self?.toggleListening()
            }
        }
        hotkeyManager.onKeyUp = nil

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

            amplitudeProvider.startPolling { [weak self] in
                self?.audioCaptureManager.currentAudioLevel ?? 0
            }
            floatingPanel?.show()
            Logger.app.info("Listening started — waveform visible")
        } catch {
            updateState(previousState)
            Logger.app.error("Failed to start audio capture: \(error)")
        }
    }

    private func stopListeningAndTranscribe() async {
        guard state == .listening else { return }

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

        if let text = await transcriptionEngine.transcribe(audioSamples: samples) {
            onTranscription?(text)
            textInsertionService.insertText(text)
            Logger.app.info("Inserted transcription: \"\(text)\"")
        } else {
            Logger.app.info("No transcription result")
        }

        updateState(.idle)
    }

    private func updateState(_ newState: AppState) {
        state = newState
        onStateChanged?(newState)
    }
}
