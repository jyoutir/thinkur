import SwiftUI
import os

@MainActor
@Observable
final class AppCoordinator {
    let services: ServiceContainer
    private let viewModels: ViewModelFactory
    private let modelLoadCoordinator: ModelLoadCoordinator
    let updaterService: UpdaterService

    private var hasSetup = false

    // Convenience accessors
    var settings: SettingsManager { services.settings }
    var sharedState: SharedAppState { services.sharedState }
    var permissionManager: PermissionManager { services.permissionManager }
    var licenseManager: LicenseManager { services.licenseManager }
    var telemetryService: TelemetryService { services.telemetryService }

    var recordingViewModel: RecordingViewModel { viewModels.recordingViewModel }
    var homeViewModel: HomeViewModel { viewModels.homeViewModel }
    var shortcutsViewModel: ShortcutsViewModel { viewModels.shortcutsViewModel }
    var styleViewModel: StyleViewModel { viewModels.styleViewModel }
    var insightsViewModel: InsightsViewModel { viewModels.insightsViewModel }
    var onboardingViewModel: OnboardingViewModel { viewModels.onboardingViewModel }
    var integrationsViewModel: IntegrationsViewModel { viewModels.integrationsViewModel }
    var meetingViewModel: MeetingViewModel { viewModels.meetingViewModel }
    var meetingCoordinator: MeetingCoordinator { viewModels.meetingCoordinator }

    init() {
        let services = ServiceContainer()
        self.services = services
        self.viewModels = ViewModelFactory(services: services)
        self.modelLoadCoordinator = ModelLoadCoordinator(
            engine: services.transcriptionEngine,
            sharedState: services.sharedState,
            telemetryService: services.telemetryService
        )
        self.updaterService = UpdaterService(settings: services.settings)

        // Check permissions synchronously so RootView has correct state on first render.
        // All three checks (AXIsProcessTrusted, recordPermission, CGPreflightListenEventAccess)
        // are synchronous system calls — safe to call here.
        services.permissionManager.checkAll()

        Task { [weak self] in
            await self?.setup()
        }
    }

    private func setup() async {
        guard !hasSetup else { return }
        hasSetup = true

        MediaControlService.restoreIfNeeded()

        // Start model loading concurrently — runs alongside permission setup
        async let modelLoad: () = modelLoadCoordinator.loadModel()

        // permissionManager.checkAll() already ran synchronously in init()

        services.telemetryService.initialize()
        services.frontmostAppDetector.startObserving()
        recordingViewModel.setupHotkey()

        // Wire up window visibility check so HotkeyManager doesn't hardcode window identifiers
        services.hotkeyManager.isAppWindowVisible = {
            NSApp.windows.contains {
                $0.identifier?.rawValue.contains("main") == true && $0.isVisible
            }
        }

        await services.licenseManager.validateOnLaunch()
        await modelLoad
    }

    func updateHotkey() {
        services.hotkeyManager.stop()
        services.hotkeyManager.targetKeyCode = settings.hotkeyCode
        services.hotkeyManager.targetModifiers = CGEventFlags(rawValue: UInt64(settings.hotkeyModifiers))
        _ = services.hotkeyManager.start()
    }

    func clearAllHistory() async {
        try? await services.analyticsService.clearAllHistory()
        await homeViewModel.loadData()
        await insightsViewModel.loadData()
    }
}
