import Sparkle
import os

@MainActor
@Observable
final class UpdaterService {
    private let controller: SPUStandardUpdaterController
    private let delegate: UpdaterDelegate

    private(set) var updateAvailable = false
    private(set) var availableVersion: String?

    private var updater: SPUUpdater { controller.updater }

    init(settings: SettingsManager) {
        let delegate = UpdaterDelegate()
        self.delegate = delegate
        self.controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: delegate,
            userDriverDelegate: nil
        )

        delegate.onUpdateFound = { [weak self] version in
            self?.updateAvailable = true
            self?.availableVersion = version
        }

        let u = updater
        u.automaticallyChecksForUpdates = settings.automaticUpdates
        u.updateCheckInterval = 4 * 60 * 60

        do {
            try u.start()
        } catch {
            Logger.app.error("Sparkle updater failed to start: \(error.localizedDescription)")
        }

        // Check shortly after launch so the sidebar button appears without waiting for the 4hr schedule
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            self?.updater.checkForUpdatesInBackground()
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
}

// MARK: - Sparkle Delegate

private final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    var onUpdateFound: ((_ version: String) -> Void)?

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let version = item.displayVersionString
        Task { @MainActor [onUpdateFound] in
            onUpdateFound?(version)
        }
    }
}
