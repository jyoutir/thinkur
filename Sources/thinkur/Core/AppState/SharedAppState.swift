import Foundation

@MainActor
@Observable
final class SharedAppState {
    var appState: AppState = .loading
    var lastTranscription: String = ""
    var isModelReady: Bool = false
    var isModelLoading: Bool = false
    var modelLoadingMessage: String = ""
}
