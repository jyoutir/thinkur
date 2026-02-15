import Foundation
import os
import WhisperKit

@MainActor
final class TranscriptionEngine: ObservableObject, Transcribing {
    @Published var isLoaded = false
    @Published var isLoading = false
    @Published var loadingMessage = ""
    @Published var errorMessage: String?
    private(set) var lastWordTimings: [WordTimingInfo] = []

    private var whisperKit: WhisperKit?

    func loadModel() async {
        guard !isLoading, !isLoaded else { return }

        isLoading = true
        loadingMessage = "Downloading model..."
        errorMessage = nil

        do {
            let config = WhisperKitConfig(
                model: Constants.whisperModel,
                verbose: false,
                logLevel: .none
            )
            Logger.transcription.info("Loading WhisperKit model: \(Constants.whisperModel)")

            whisperKit = try await WhisperKit(config)

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
