import Foundation
import os

@MainActor
final class ModelLoadCoordinator {
    private let transcriptionEngine: TranscriptionEngine
    private let sharedState: SharedAppState
    private let settings: SettingsManager

    init(transcriptionEngine: TranscriptionEngine, sharedState: SharedAppState, settings: SettingsManager) {
        self.transcriptionEngine = transcriptionEngine
        self.sharedState = sharedState
        self.settings = settings
    }

    func loadModel() async {
        sharedState.appState = .loading
        await transcriptionEngine.loadModel(name: settings.modelSize)

        if transcriptionEngine.isLoaded {
            sharedState.appState = .idle
            sharedState.isModelReady = true
            Logger.app.info("thinkur ready")
        } else {
            let message = transcriptionEngine.errorMessage ?? "Model failed to load"
            sharedState.appState = .error(message)
            Logger.app.error("Failed to load transcription model: \(message)")
        }
    }
}
