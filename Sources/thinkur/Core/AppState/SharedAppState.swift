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
    var transcriptionVersion: Int = 0
    var lastSmartHomeAction: String?
    var isMeetingActive: Bool = false

    // MARK: - Free Tier
    var freeTierExhausted: Bool = false
    var freeWordsUsed: Int = 0
    var isUserLicensed: Bool = false

    var canTranscribe: Bool { isUserLicensed || !freeTierExhausted }
    var freeWordsRemaining: Int { max(0, Constants.freeWordLimit - freeWordsUsed) }
    var isFreeTier: Bool { !isUserLicensed }
}
