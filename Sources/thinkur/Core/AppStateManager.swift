import Cocoa
import os
import SwiftUI

enum AppState: Equatable {
    case idle
    case loading
    case listening
    case processing
    case error(String)
}

@MainActor
final class AppStateManager: ObservableObject {
    @Published var state: AppState = .loading
    @Published var lastTranscription: String = ""
    private var hasSetup = false

    let permissionManager = PermissionManager()
    let transcriptionEngine = TranscriptionEngine()
    let amplitudeProvider = AudioAmplitudeProvider()
    let frontmostAppDetector = FrontmostAppDetector()
    private let audioCaptureManager = AudioCaptureManager()
    private let hotkeyManager = HotkeyManager()
    private let textInsertionService = TextInsertionService()

    private var floatingPanel: FloatingIndicatorPanel?

    init() {
        // Kick off async setup after init completes
        Task { [weak self] in
            await self?.setup()
        }
    }

    var menuBarIcon: String {
        switch state {
        case .idle: return "mic"
        case .loading: return "arrow.down.circle"
        case .listening: return "mic.fill"
        case .processing: return "ellipsis.circle"
        case .error: return "exclamationmark.triangle"
        }
    }

    var statusText: String {
        switch state {
        case .idle: return "Ready — tap Tab to speak"
        case .loading: return transcriptionEngine.loadingMessage.isEmpty
            ? "Loading..." : transcriptionEngine.loadingMessage
        case .listening: return "Listening — tap Tab to stop"
        case .processing: return "Transcribing..."
        case .error(let msg): return msg
        }
    }

    var statusColor: Color {
        switch state {
        case .idle: return .green
        case .loading: return .yellow
        case .listening: return .red
        case .processing: return .orange
        case .error: return .red
        }
    }

    func setup() async {
        guard !hasSetup else { return }
        hasSetup = true

        // Check permissions
        permissionManager.checkAll()

        if !permissionManager.microphoneGranted {
            await permissionManager.requestMicrophone()
        }

        if !permissionManager.accessibilityGranted {
            permissionManager.requestAccessibility()
        }

        // Start frontmost app detection
        frontmostAppDetector.startObserving()

        // Create floating panel (hidden initially)
        floatingPanel = FloatingIndicatorPanel(amplitudeProvider: amplitudeProvider)

        // Start hotkey manager — tap-to-start / tap-to-end
        setupHotkey()

        // Load WhisperKit model
        state = .loading
        await transcriptionEngine.loadModel()

        if transcriptionEngine.isLoaded {
            state = .idle
            Logger.app.info("thinkur ready")
        } else {
            state = .error("Model failed to load")
            Logger.app.error("Failed to load transcription model")
        }
    }

    private func setupHotkey() {
        // Tap-to-start / tap-to-end: single callback toggles state
        hotkeyManager.onKeyDown = { [weak self] in
            Task { @MainActor in
                self?.toggleListening()
            }
        }

        // onKeyUp is unused in tap-to-toggle mode
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

    /// Tap Tab once to start listening, tap again to stop and transcribe.
    private func toggleListening() {
        switch state {
        case .listening:
            // Stop listening and transcribe
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
            state = .listening

            // Show waveform overlay and start polling audio levels
            amplitudeProvider.startPolling { [weak self] in
                self?.audioCaptureManager.currentAudioLevel ?? 0
            }
            floatingPanel?.show()
            Logger.app.info("Listening started — waveform visible")
        } catch {
            state = previousState
            Logger.app.error("Failed to start audio capture: \(error)")
        }
    }

    private func stopListeningAndTranscribe() async {
        guard state == .listening else { return }

        // Hide waveform overlay and stop polling
        amplitudeProvider.stopPolling()
        floatingPanel?.hide()

        let samples = audioCaptureManager.stopCapture()
        state = .processing

        // Skip transcription for very short recordings (< 0.3s)
        let duration = Double(samples.count) / Constants.sampleRate
        guard duration >= 0.3 else {
            Logger.app.info("Recording too short (\(String(format: "%.1f", duration))s), skipping")
            state = .idle
            return
        }

        // Wait for model if it's still loading
        if !transcriptionEngine.isLoaded {
            Logger.app.info("Waiting for model to finish loading...")
            while !transcriptionEngine.isLoaded && transcriptionEngine.isLoading {
                try? await Task.sleep(for: .milliseconds(200))
            }
        }

        if let text = await transcriptionEngine.transcribe(audioSamples: samples) {
            lastTranscription = text
            textInsertionService.insertText(text)
            Logger.app.info("Inserted transcription: \"\(text)\"")
        } else {
            Logger.app.info("No transcription result")
        }

        state = .idle
    }
}
