import Cocoa
import os

@MainActor
@Observable
final class RecordingViewModel {
    var state: AppState { coordinator.state }

    private let coordinator: RecordingCoordinator
    private let hotkeyManager: any HotkeyListening
    private let settings: SettingsManager
    private let sharedState: SharedAppState

    init(
        coordinator: RecordingCoordinator,
        hotkeyManager: any HotkeyListening,
        settings: SettingsManager,
        sharedState: SharedAppState
    ) {
        self.coordinator = coordinator
        self.hotkeyManager = hotkeyManager
        self.settings = settings
        self.sharedState = sharedState
    }

    var isModelReady: Bool {
        get { sharedState.isModelReady }
        set { sharedState.isModelReady = newValue }
    }

    func setupHotkey() {
        if let hm = hotkeyManager as? HotkeyManager {
            hm.targetKeyCode = settings.hotkeyCode
            hm.targetModifiers = CGEventFlags(rawValue: UInt64(settings.hotkeyModifiers))
        }
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
            if state == .idle || state == .loading {
                coordinator.startRecording()
            }
        } else {
            toggleListening()
        }
    }

    private func handleKeyUp() {
        if settings.hotkeyHoldMode && state == .listening {
            Task {
                await coordinator.stopAndTranscribe()
            }
        }
    }

    func toggleRecording() {
        toggleListening()
    }

    private func toggleListening() {
        switch state {
        case .listening:
            Task {
                await coordinator.stopAndTranscribe()
            }
        case .idle, .loading:
            coordinator.startRecording()
        default:
            Logger.app.warning("Cannot toggle listening: state is \(String(describing: self.state))")
        }
    }
}
