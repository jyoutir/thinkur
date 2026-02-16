import SwiftUI

@MainActor
@Observable
final class MenuBarViewModel {
    // Keep stored properties for backward compatibility with callback wiring
    var appState: AppState = .loading
    var lastTranscription: String = ""

    private let frontmostAppDetector: FrontmostAppDetector
    private let sharedState: SharedAppState?

    init(frontmostAppDetector: FrontmostAppDetector, sharedState: SharedAppState? = nil) {
        self.frontmostAppDetector = frontmostAppDetector
        self.sharedState = sharedState
    }

    /// Resolved state: prefers SharedAppState if available, falls back to stored property
    var currentAppState: AppState {
        sharedState?.appState ?? appState
    }

    var currentTranscription: String {
        sharedState?.lastTranscription ?? lastTranscription
    }

    var menuBarIcon: String {
        switch currentAppState {
        case .idle: return "mic"
        case .loading: return "arrow.down.circle"
        case .listening: return "mic.fill"
        case .processing: return "ellipsis.circle"
        case .error: return "exclamationmark.triangle"
        }
    }

    var statusText: String {
        switch currentAppState {
        case .idle: return "Ready — tap Tab to speak"
        case .loading: return "Loading..."
        case .listening: return "Listening — tap Tab to stop"
        case .processing: return "Transcribing..."
        case .error(let msg): return msg
        }
    }

    var statusColor: Color {
        switch currentAppState {
        case .idle: return .green
        case .loading: return .yellow
        case .listening: return .red
        case .processing: return .orange
        case .error: return .red
        }
    }

    var isModelLoading: Bool {
        sharedState?.isModelLoading ?? false
    }

    var modelLoadingMessage: String {
        sharedState?.modelLoadingMessage ?? ""
    }

    var frontmostAppName: String {
        frontmostAppDetector.appName
    }
}
