import Foundation
@testable import thinkur

@MainActor
final class MockTranscribing: Transcribing {
    var isLoaded = true
    var isLoading = false
    var loadingMessage = ""
    var errorMessage: String?
    var lastWordTimings: [WordTimingInfo] = []
    private(set) var lastAudioSampleCount = 0
    var transcriptionResult: String? = "hello world"

    func loadModel(name: String? = nil) async {
        isLoaded = true
        isLoading = false
    }

    func transcribe(audioSamples: [Float]) async -> String? {
        lastAudioSampleCount = audioSamples.count
        return transcriptionResult
    }
}
