import Foundation

@MainActor
@Observable
final class SharedAppState {
    var appState: AppState = .idle
    var lastTranscription: String = ""
    var isModelReady: Bool = false
    var isModelLoading: Bool = false
    var modelLoadingMessage: String = ""
    var transcriptionVersion: Int = 0
    var lastSmartHomeAction: String?
}
