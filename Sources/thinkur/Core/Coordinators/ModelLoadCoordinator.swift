import Foundation
import os

@MainActor
final class ModelLoadCoordinator {
    private let transcriptionEngine: TranscriptionEngine
    private let sharedState: SharedAppState
    private var upgradeTask: Task<Void, Never>?

    private static let modelFolderKeyPrefix = "com.thinkur.modelFolder."

    init(transcriptionEngine: TranscriptionEngine, sharedState: SharedAppState) {
        self.transcriptionEngine = transcriptionEngine
        self.sharedState = sharedState
    }

    func loadModel() async {
        sharedState.appState = .loading
        sharedState.isModelLoading = true
        sharedState.modelLoadingMessage = "Preparing your voice model\u{2026}"
        sharedState.modelDownloadProgress = 0.0

        // Poll TranscriptionEngine state and forward to SharedAppState
        let pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                let message = self.transcriptionEngine.loadingMessage
                if !message.isEmpty {
                    self.sharedState.modelLoadingMessage = message
                }
                self.sharedState.modelDownloadProgress = self.transcriptionEngine.downloadProgress
                try? await Task.sleep(for: .milliseconds(200))
            }
        }

        let preferredModel = Constants.whisperModel
        let quickModel = Constants.quickStartModel

        // If preferred model is cached from a previous session, load it directly.
        // Otherwise, load the quick-start model first for instant readiness.
        let useQuickStart = preferredModel != quickModel && !isModelCached(preferredModel)
        let modelToLoad = useQuickStart ? quickModel : preferredModel

        await transcriptionEngine.loadModel(name: modelToLoad)

        // Fallback if primary load fails
        if !transcriptionEngine.isLoaded && modelToLoad != quickModel {
            Logger.app.warning("Model '\(modelToLoad)' failed, falling back to \(quickModel)")
            await transcriptionEngine.loadModel(name: quickModel)
        }

        pollingTask.cancel()

        if transcriptionEngine.isLoaded {
            if let folder = transcriptionEngine.currentModelFolder {
                cacheModelFolder(folder, for: transcriptionEngine.currentModel)
            }

            sharedState.appState = .idle
            sharedState.isModelReady = true
            sharedState.isModelLoading = false
            sharedState.modelLoadingMessage = ""
            sharedState.modelDownloadProgress = 1.0
            Logger.app.info("thinkur ready with model: \(self.transcriptionEngine.currentModel)")

            // Background upgrade if we loaded the quick-start model
            if transcriptionEngine.currentModel != preferredModel {
                upgradeModelInBackground(to: preferredModel)
            }
        } else {
            let message = transcriptionEngine.errorMessage ?? "Model failed to load"
            sharedState.appState = .error(message)
            sharedState.isModelLoading = false
            sharedState.modelLoadingMessage = ""
            Logger.app.error("Failed to load transcription model: \(message)")
        }
    }

    // MARK: - Background Upgrade

    private func upgradeModelInBackground(to model: String) {
        sharedState.isUpgradingModel = true
        Logger.app.info("Starting background upgrade to \(model)")

        upgradeTask = Task { [weak self] in
            guard let self else { return }
            do {
                let (newKit, folder) = try await self.transcriptionEngine.prepareModel(name: model)

                // Wait for idle state before swapping (don't interrupt active transcription)
                while self.sharedState.appState != .idle {
                    if Task.isCancelled { return }
                    try? await Task.sleep(for: .milliseconds(200))
                }

                self.transcriptionEngine.swapModel(to: newKit, name: model, folder: folder)
                self.cacheModelFolder(folder, for: model)
                self.sharedState.isUpgradingModel = false
                Logger.app.info("Background upgrade to \(model) complete")
            } catch {
                self.sharedState.isUpgradingModel = false
                Logger.app.error("Background upgrade to \(model) failed: \(error)")
            }
        }
    }

    // MARK: - Model Cache

    private func isModelCached(_ model: String) -> Bool {
        guard let path = UserDefaults.standard.string(forKey: Self.modelFolderKeyPrefix + model) else {
            return false
        }
        return FileManager.default.fileExists(atPath: path)
    }

    private func cacheModelFolder(_ path: String, for model: String) {
        UserDefaults.standard.set(path, forKey: Self.modelFolderKeyPrefix + model)
    }
}
