import SwiftUI

@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published var appState: AppState = .loading
    @Published var lastTranscription: String = ""

    private let frontmostAppDetector: FrontmostAppDetector

    init(frontmostAppDetector: FrontmostAppDetector) {
        self.frontmostAppDetector = frontmostAppDetector
    }

    var menuBarIcon: String {
        switch appState {
        case .idle: return "mic"
        case .loading: return "arrow.down.circle"
        case .listening: return "mic.fill"
        case .processing: return "ellipsis.circle"
        case .error: return "exclamationmark.triangle"
        }
    }

    var statusText: String {
        switch appState {
        case .idle: return "Ready — tap Tab to speak"
        case .loading: return "Loading..."
        case .listening: return "Listening — tap Tab to stop"
        case .processing: return "Transcribing..."
        case .error(let msg): return msg
        }
    }

    var statusColor: Color {
        switch appState {
        case .idle: return .green
        case .loading: return .yellow
        case .listening: return .red
        case .processing: return .orange
        case .error: return .red
        }
    }

    var frontmostAppName: String {
        frontmostAppDetector.appName
    }
}
