import Foundation

@MainActor
@Observable
final class TranscriptionViewModel {
    var isLoading = false
    var loadingMessage = ""

    private let transcriptionEngine: TranscriptionEngine

    init(transcriptionEngine: TranscriptionEngine) {
        self.transcriptionEngine = transcriptionEngine
    }

    func sync() {
        isLoading = transcriptionEngine.isLoading
        loadingMessage = transcriptionEngine.loadingMessage
    }
}
