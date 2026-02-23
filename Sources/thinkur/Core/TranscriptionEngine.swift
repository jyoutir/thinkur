import Foundation
import os
import WhisperKit

@MainActor
@Observable
final class TranscriptionEngine: Transcribing {
    var isLoaded = false
    var isLoading = false
    var loadingMessage = ""
    var errorMessage: String?
    var downloadProgress: Double = 0.0
    private(set) var lastWordTimings: [WordTimingInfo] = []

    private var whisperKit: WhisperKit?
    private(set) var currentModel: String = ""
    private(set) var currentModelFolder: String?

    /// Two-phase model load: download (with progress), then init with prewarm.
    func loadModel(name: String? = nil) async {
        let modelName = name ?? Constants.whisperModel

        // If already loaded with the same model, skip
        if isLoaded && currentModel == modelName { return }

        // If switching models, reset state
        if isLoaded {
            whisperKit = nil
            isLoaded = false
        }

        guard !isLoading else { return }

        isLoading = true
        downloadProgress = 0.0
        errorMessage = nil

        do {
            // Phase 1: Download with progress tracking
            loadingMessage = "Downloading model\u{2026}"
            Logger.transcription.info("Downloading WhisperKit model: \(modelName)")

            let modelFolder = try await WhisperKit.download(
                variant: modelName,
                downloadBase: Constants.appSupportDirectory,
                progressCallback: { [weak self] progress in
                    let fraction = progress.fractionCompleted
                    Task { @MainActor [weak self] in
                        self?.downloadProgress = fraction
                    }
                }
            )

            downloadProgress = 1.0

            // Phase 2: Init from local folder with prewarm (Neural Engine compile)
            loadingMessage = "Preparing model\u{2026}"
            Logger.transcription.info("Loading WhisperKit model from: \(modelFolder.path)")

            let config = WhisperKitConfig(
                modelFolder: modelFolder.path,
                verbose: false,
                logLevel: .none,
                prewarm: true,
                load: true,
                download: false
            )
            whisperKit = try await WhisperKit(config)

            isLoaded = true
            currentModel = modelName
            currentModelFolder = modelFolder.path
            loadingMessage = ""
            Logger.transcription.info("WhisperKit model loaded successfully")
        } catch {
            errorMessage = error.localizedDescription
            loadingMessage = ""
            Logger.transcription.error("Failed to load WhisperKit model: \(error)")
        }

        isLoading = false
    }

    /// Download and prepare a model without setting it as active.
    /// Returns the WhisperKit instance and model folder path.
    func prepareModel(name: String) async throws -> (WhisperKit, String) {
        Logger.transcription.info("Background: downloading model \(name)")
        let modelFolder = try await WhisperKit.download(
            variant: name,
            downloadBase: Constants.appSupportDirectory
        )

        Logger.transcription.info("Background: loading and prewarming model \(name)")
        let config = WhisperKitConfig(
            modelFolder: modelFolder.path,
            verbose: false,
            logLevel: .none,
            prewarm: true,
            load: true,
            download: false
        )
        let newKit = try await WhisperKit(config)
        return (newKit, modelFolder.path)
    }

    /// Hot-swap to a prepared model instance, cleaning up the old model folder.
    func swapModel(to newKit: WhisperKit, name: String, folder: String) {
        let oldFolder = currentModelFolder
        whisperKit = newKit
        currentModel = name
        currentModelFolder = folder
        isLoaded = true
        Logger.transcription.info("Swapped to model: \(name)")

        if let old = oldFolder, old != folder {
            do {
                try FileManager.default.removeItem(atPath: old)
                Logger.transcription.info("Cleaned up old model folder: \(old)")
            } catch {
                Logger.transcription.warning("Failed to clean up old model: \(error)")
            }
        }
    }

    func transcribe(audioSamples: [Float]) async -> String? {
        guard let whisperKit else {
            Logger.transcription.warning("Transcription requested but model not loaded")
            return nil
        }

        let sampleCount = audioSamples.count
        let duration = Double(sampleCount) / Constants.sampleRate
        Logger.transcription.info("Transcribing \(sampleCount) samples (\(String(format: "%.1f", duration))s)")

        do {
            let options = DecodingOptions(wordTimestamps: true)
            let results = try await whisperKit.transcribe(audioArray: audioSamples, decodeOptions: options)

            // Extract word timings
            let allWordTimings = results.flatMap { result in
                result.segments.flatMap { segment in
                    (segment.words ?? []).map { word in
                        WordTimingInfo(word: word.word, start: Float(word.start), end: Float(word.end))
                    }
                }
            }

            // Filter Whisper noise tokens from word timings
            lastWordTimings = allWordTimings.filter { !WhisperArtifactFilter.isArtifact($0.word) }

            let rawText = results
                .compactMap { $0.text }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Filter noise tokens from text; return nil if nothing remains
            guard let text = WhisperArtifactFilter.strip(rawText), !text.isEmpty else {
                Logger.transcription.info("Transcription suppressed \u{2014} only noise tokens detected")
                return nil
            }

            Logger.transcription.debug(
                "Transcription produced \(text.count) chars with \(self.lastWordTimings.count) word timings"
            )
            return text
        } catch {
            Logger.transcription.error("Transcription failed: \(error)")
            return nil
        }
    }
}
