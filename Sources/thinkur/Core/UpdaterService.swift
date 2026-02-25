import Sparkle
import os

@MainActor
@Observable
final class UpdaterService {
    private let controller: SPUStandardUpdaterController
    private let delegate: UpdaterDelegate

    private(set) var updateAvailable = false
    private(set) var availableVersion: String?
    private(set) var releaseNotesHTML: String?

    /// Release notes with HTML stripped for compact sidebar display.
    private(set) var releaseNotes: String?

    private var updater: SPUUpdater { controller.updater }

    init(settings: SettingsManager) {
        let delegate = UpdaterDelegate()
        self.delegate = delegate
        self.controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: delegate,
            userDriverDelegate: nil
        )

        delegate.onUpdateFound = { [weak self] version, html in
            self?.updateAvailable = true
            self?.availableVersion = version
            self?.releaseNotesHTML = html
            self?.releaseNotes = html.flatMap { Self.stripHTML($0) }
        }
        delegate.onNoUpdateFound = { [weak self] in
            self?.updateAvailable = false
            self?.availableVersion = nil
            self?.releaseNotesHTML = nil
            self?.releaseNotes = nil
        }

        let u = updater
        u.automaticallyChecksForUpdates = settings.automaticUpdates
        u.updateCheckInterval = 4 * 60 * 60

        do {
            try u.start()
        } catch {
            Logger.app.error("Sparkle updater failed to start: \(error.localizedDescription)")
        }

        observeSettings(settings)
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }

    // MARK: - Settings Observation

    private func observeSettings(_ settings: SettingsManager) {
        withObservationTracking {
            _ = settings.automaticUpdates
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updater.automaticallyChecksForUpdates = settings.automaticUpdates
                self.observeSettings(settings)
            }
        }
    }

    // MARK: - HTML Stripping

    private static let htmlTagPattern = try! NSRegularExpression(pattern: "<[^>]+>")
    private static let excessNewlinesPattern = try! NSRegularExpression(pattern: "\n{3,}")

    private static let entityMap: [(String, String)] = [
        ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
        ("&nbsp;", " "), ("&quot;", "\""), ("&#39;", "'"),
    ]

    private static func stripHTML(_ html: String) -> String {
        var result = html
        // Structural tags → whitespace
        result = result.replacingOccurrences(of: "<br", with: "\n<br", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "</p>", with: "\n")
        result = result.replacingOccurrences(of: "<li>", with: "\u{2022} ")
        result = result.replacingOccurrences(of: "</li>", with: "\n")
        // Strip all remaining tags
        let range = NSRange(result.startIndex..., in: result)
        result = htmlTagPattern.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        // Decode entities
        for (entity, replacement) in entityMap {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        // Collapse excessive newlines
        let cleanRange = NSRange(result.startIndex..., in: result)
        result = excessNewlinesPattern.stringByReplacingMatches(in: result, range: cleanRange, withTemplate: "\n\n")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Sparkle Delegate

private final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    var onUpdateFound: ((_ version: String, _ notes: String?) -> Void)?
    var onNoUpdateFound: (() -> Void)?

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let version = item.displayVersionString
        let notes = item.itemDescription
        Task { @MainActor [onUpdateFound] in
            onUpdateFound?(version, notes)
        }
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        Task { @MainActor [onNoUpdateFound] in
            onNoUpdateFound?()
        }
    }
}
