import Sparkle
import os

@MainActor
@Observable
final class UpdaterService {
    private let controller: SPUStandardUpdaterController?
    private let updaterDelegate: UpdaterDelegate?
    private let userDriverDelegate: UserDriverDelegate?

    let isEnabled: Bool = AppRuntimeConfiguration.isSparkleEnabled

    private(set) var updateAvailable = false
    private(set) var availableVersion: String?

    private var updater: SPUUpdater? { controller?.updater }

    init(settings: SettingsManager) {
        guard isEnabled else {
            self.controller = nil
            self.updaterDelegate = nil
            self.userDriverDelegate = nil
            Logger.app.info("Sparkle updater disabled for dev build")
            return
        }

        let updaterDelegate = UpdaterDelegate()
        let userDriverDelegate = UserDriverDelegate()
        self.updaterDelegate = updaterDelegate
        self.userDriverDelegate = userDriverDelegate
        self.controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: updaterDelegate,
            userDriverDelegate: userDriverDelegate
        )

        updaterDelegate.onUpdateFound = { [weak self] version in
            self?.updateAvailable = true
            self?.availableVersion = version
        }

        userDriverDelegate.onUpdateFound = { [weak self] version in
            self?.updateAvailable = true
            self?.availableVersion = version
        }

        guard let u = updater else { return }
        u.automaticallyChecksForUpdates = settings.automaticUpdates
        u.updateCheckInterval = 4 * 60 * 60

        do {
            try u.start()
        } catch {
            Logger.app.error("Sparkle updater failed to start: \(error.localizedDescription)")
        }

        // Probe after launch so the sidebar button appears without waiting for the 4hr schedule.
        // checkForUpdateInformation() fires didFindValidUpdate without showing any UI.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            self?.updater?.checkForUpdateInformation()
        }

        observeSettings(settings)
    }

    func checkForUpdates() {
        guard isEnabled else { return }
        updater?.checkForUpdates()
    }

    // MARK: - Settings Observation

    private func observeSettings(_ settings: SettingsManager) {
        withObservationTracking {
            _ = settings.automaticUpdates
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, let updater = self.updater else { return }
                updater.automaticallyChecksForUpdates = settings.automaticUpdates
                self.observeSettings(settings)
            }
        }
    }
}

// MARK: - SPUUpdaterDelegate

private final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    var onUpdateFound: ((_ version: String) -> Void)?

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        Logger.app.info("Sparkle: found valid update — v\(item.displayVersionString) (build \(item.versionString))")
        let version = item.displayVersionString
        Task { @MainActor [onUpdateFound] in
            onUpdateFound?(version)
        }
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        Logger.app.info("Sparkle: no update found (current build: \(build))")
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        Logger.app.error("Sparkle: aborted — \(error.localizedDescription)")
    }
}

// MARK: - SPUStandardUserDriverDelegate (Gentle Scheduled Update Reminders)

private final class UserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    var onUpdateFound: ((_ version: String) -> Void)?

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        // Return false → Sparkle won't show its own alert for scheduled checks.
        // We show our sidebar button instead.
        false
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        // When we declined to handle (handleShowingUpdate == false), ensure our button shows.
        if !handleShowingUpdate {
            let version = update.displayVersionString
            Task { @MainActor [onUpdateFound] in
                onUpdateFound?(version)
            }
        }
    }
}
