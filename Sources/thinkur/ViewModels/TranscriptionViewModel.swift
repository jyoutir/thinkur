import Foundation

@MainActor
final class TranscriptionViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var loadingMessage = ""

    private let transcriptionEngine: TranscriptionEngine

    init(transcriptionEngine: TranscriptionEngine) {
        self.transcriptionEngine = transcriptionEngine
    }

    func syncState() {
        isLoading = transcriptionEngine.isLoading
        loadingMessage = transcriptionEngine.loadingMessage
    }
}
