import Foundation
import Combine

@MainActor
final class TranscriptionViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var loadingMessage = ""

    private let transcriptionEngine: TranscriptionEngine

    init(transcriptionEngine: TranscriptionEngine) {
        self.transcriptionEngine = transcriptionEngine
        transcriptionEngine.$isLoading.assign(to: &$isLoading)
        transcriptionEngine.$loadingMessage.assign(to: &$loadingMessage)
    }
}
