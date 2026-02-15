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

    func loadModel() async {
        guard !isLoading, !isLoaded else { return }

        isLoading = true
        errorMessage = nil

        do {
            let config = WhisperKitConfig(
                model: Constants.whisperModel,
                downloadBase: Constants.appSupportDirectory,
                verbose: false,
                logLevel: .none
            )
            Logger.transcription.info("Loading WhisperKit model: \(Constants.whisperModel)")

            loadingMessage = "Downloading model..."
            whisperKit = try await WhisperKit(config)
            loadingMessage = "Loading model..."

            isLoaded = true
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
            lastWordTimings = results.flatMap { result in
                result.segments.flatMap { segment in
                    (segment.words ?? []).map { word in
                        WordTimingInfo(word: word.word, start: Float(word.start), end: Float(word.end))
                    }
                }
            }

            let text = results
                .compactMap { $0.text }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            Logger.transcription.info("Transcription result: \"\(text)\" (\(self.lastWordTimings.count) word timings)")
            return text.isEmpty ? nil : text
        } catch {
            Logger.transcription.error("Transcription failed: \(error)")
            return nil
        }
    }
}
