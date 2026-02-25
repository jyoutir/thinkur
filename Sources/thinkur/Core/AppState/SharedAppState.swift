import Foundation

@MainActor
@Observable
final class SharedAppState {
    var appState: AppState = .idle
    var lastTranscription: String = ""
    var isModelReady: Bool = false
    var isModelLoading: Bool = false
    var modelLoadingMessage: String = ""
    var modelDownloadProgress: Double = 0.0
    var currentModelName: String = ""
    var transcriptionVersion: Int = 0
    var lastSmartHomeAction: String?
}
