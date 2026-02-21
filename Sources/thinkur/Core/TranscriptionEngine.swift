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
    private(set) var lastWordTimings: [WordTimingInfo] = []

    private var whisperKit: WhisperKit?
    private(set) var currentModel: String = ""

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
        errorMessage = nil

        do {
            let config = WhisperKitConfig(
                model: modelName,
                downloadBase: Constants.appSupportDirectory,
                verbose: false,
                logLevel: .none
            )
            Logger.transcription.info("Loading WhisperKit model: \(modelName)")

            loadingMessage = "Downloading model..."
            whisperKit = try await WhisperKit(config)
            loadingMessage = "Loading model..."

            isLoaded = true
            currentModel = modelName
            loadingMessage = ""
            Logger.transcription.info("WhisperKit model loaded successfully")
        } catch {
            errorMessage = error.localizedDescription
            loadingMessage = ""
            Logger.transcription.error("Failed to load WhisperKit model: \(error)")
        }

        isLoading = false
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
                Logger.transcription.info("Transcription suppressed — only noise tokens detected")
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
