import Foundation
import os

@MainActor
final class ModelLoadCoordinator {
    private let engine: ParakeetTranscriptionEngine
    private let sharedState: SharedAppState
    private let telemetryService: TelemetryService

    init(engine: ParakeetTranscriptionEngine, sharedState: SharedAppState, telemetryService: TelemetryService) {
        self.engine = engine
        self.sharedState = sharedState
        self.telemetryService = telemetryService
    }

    func loadModel() async {
        sharedState.appState = .loading
        sharedState.isModelReady = false
        sharedState.isModelLoading = true
        sharedState.modelLoadingMessage = "Loading voice model\u{2026}"
        sharedState.modelDownloadProgress = 0.0

        let pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                let message = self.engine.loadingMessage
                if !message.isEmpty {
                    self.sharedState.modelLoadingMessage = message
                }
                self.sharedState.modelDownloadProgress = self.engine.downloadProgress
                try? await Task.sleep(for: .milliseconds(200))
            }
        }

        await engine.loadModel(name: nil)

        pollingTask.cancel()

        if engine.isLoaded {
            sharedState.appState = .idle
            sharedState.isModelReady = true
            sharedState.isModelLoading = false
            sharedState.modelLoadingMessage = ""
            sharedState.modelDownloadProgress = 1.0
            Logger.app.info("thinkur ready with Parakeet")
            cleanupLegacyWhisperKitModels()
        } else {
            let message = engine.errorMessage ?? "Model failed to load"
            sharedState.appState = .error(message)
            sharedState.isModelReady = false
            sharedState.isModelLoading = false
            sharedState.modelLoadingMessage = ""
            telemetryService.trackModelLoadError(modelName: "voice-engine", errorMessage: message)
            Logger.app.error("Failed to load Parakeet: \(message)")
        }
    }

    /// Remove legacy WhisperKit model files from app support directory.
    /// Called once after Parakeet loads successfully to reclaim disk space.
    private func cleanupLegacyWhisperKitModels() {
        let key = "hasCleanedWhisperKitModels"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let fm = FileManager.default
        let appSupport = Constants.appSupportDirectory

        // WhisperKit stored models under models/argmaxinc/ and models/openai/
        let modelsDir = appSupport.appendingPathComponent("models", isDirectory: true)
        if fm.fileExists(atPath: modelsDir.path) {
            do {
                try fm.removeItem(at: modelsDir)
                Logger.app.info("Removed legacy WhisperKit models directory")
            } catch {
                Logger.app.warning("Failed to remove legacy WhisperKit models: \(error)")
            }
        }

        UserDefaults.standard.set(true, forKey: key)
    }
}
