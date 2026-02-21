import Foundation
import os

@MainActor
final class ModelLoadCoordinator {
    private let transcriptionEngine: TranscriptionEngine
    private let sharedState: SharedAppState

    init(transcriptionEngine: TranscriptionEngine, sharedState: SharedAppState) {
        self.transcriptionEngine = transcriptionEngine
        self.sharedState = sharedState
    }

    func loadModel() async {
        sharedState.appState = .loading
        sharedState.isModelLoading = true
        sharedState.modelLoadingMessage = "Preparing your voice model\u{2026}"

        // Poll TranscriptionEngine.loadingMessage and forward to SharedAppState
        let pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                let message = self.transcriptionEngine.loadingMessage
                if !message.isEmpty {
                    self.sharedState.modelLoadingMessage = message
                }
                try? await Task.sleep(for: .milliseconds(200))
            }
        }

        await transcriptionEngine.loadModel()

        if !transcriptionEngine.isLoaded && Constants.whisperModel != "small.en" {
            Logger.app.warning("Preferred model '\(Constants.whisperModel)' failed to load, falling back to small.en")
            await transcriptionEngine.loadModel(name: "small.en")
        }

        pollingTask.cancel()

        if transcriptionEngine.isLoaded {
            sharedState.appState = .idle
            sharedState.isModelReady = true
            sharedState.isModelLoading = false
            sharedState.modelLoadingMessage = ""
            Logger.app.info("thinkur ready")
        } else {
            let message = transcriptionEngine.errorMessage ?? "Model failed to load"
            sharedState.appState = .error(message)
            sharedState.isModelLoading = false
            sharedState.modelLoadingMessage = ""
            Logger.app.error("Failed to load transcription model: \(message)")
        }
    }
}
