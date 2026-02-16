import Foundation
@testable import thinkur

@MainActor
final class MockTranscribing: Transcribing {
    var isLoaded = true
    var isLoading = false
    var loadingMessage = ""
    var errorMessage: String?
    var lastWordTimings: [WordTimingInfo] = []
    var transcriptionResult: String? = "hello world"

    func loadModel() async {
        isLoaded = true
        isLoading = false
    }

    func transcribe(audioSamples: [Float]) async -> String? {
        return transcriptionResult
    }
}
