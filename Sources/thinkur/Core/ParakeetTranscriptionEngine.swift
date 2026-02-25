import Foundation
import os
import FluidAudio

@MainActor
@Observable
final class ParakeetTranscriptionEngine: Transcribing {
    var isLoaded = false
    var isLoading = false
    var loadingMessage = ""
    var errorMessage: String?
    private(set) var lastWordTimings: [WordTimingInfo] = []

    private var asrManager: AsrManager?
    private(set) var currentVersion: AsrModelVersion?

    func loadModel(name: String?) async {
        let version: AsrModelVersion = (name == "parakeetV2") ? .v2 : .v3

        // If already loaded with the same version, skip
        if isLoaded && currentVersion == version { return }

        // If switching versions, reset
        if isLoaded {
            asrManager?.cleanup()
            asrManager = nil
            isLoaded = false
        }

        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        loadingMessage = "Downloading Parakeet model\u{2026}"

        do {
            let models = try await AsrModels.downloadAndLoad(
                to: ParakeetTranscriptionEngine.cacheDirectory(for: version),
                version: version
            )

            loadingMessage = "Preparing Parakeet model\u{2026}"
            let manager = AsrManager()
            try await manager.initialize(models: models)

            asrManager = manager
            currentVersion = version
            isLoaded = true
            loadingMessage = ""
            Logger.transcription.info("Parakeet \(version == .v2 ? "v2" : "v3") loaded successfully")
        } catch {
            errorMessage = error.localizedDescription
            loadingMessage = ""
            Logger.transcription.error("Failed to load Parakeet model: \(error)")
        }

        isLoading = false
    }

    func transcribe(audioSamples: [Float]) async -> String? {
        guard let asrManager else {
            Logger.transcription.warning("Parakeet transcription requested but model not loaded")
            return nil
        }

        let sampleCount = audioSamples.count
        let duration = Double(sampleCount) / 16_000.0
        Logger.transcription.info("Parakeet transcribing \(sampleCount) samples (\(String(format: "%.1f", duration))s)")

        do {
            let result = try await asrManager.transcribe(audioSamples, source: .microphone)

            // Map token timings to WordTimingInfo
            if let tokenTimings = result.tokenTimings {
                lastWordTimings = tokenTimings.map { timing in
                    WordTimingInfo(
                        word: timing.token,
                        start: Float(timing.startTime),
                        end: Float(timing.endTime)
                    )
                }
            } else {
                lastWordTimings = []
            }

            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                Logger.transcription.info("Parakeet returned empty text")
                return nil
            }

            Logger.transcription.debug(
                "Parakeet produced \(text.count) chars in \(String(format: "%.3f", result.processingTime))s (RTFx: \(String(format: "%.1f", result.rtfx)))"
            )
            return text
        } catch {
            Logger.transcription.error("Parakeet transcription failed: \(error)")
            return nil
        }
    }

    // MARK: - Cache Directory

    private static func cacheDirectory(for version: AsrModelVersion) -> URL {
        let subdir = version == .v2 ? "parakeet-v2" : "parakeet-v3"
        let dir = Constants.appSupportDirectory.appendingPathComponent(subdir, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
