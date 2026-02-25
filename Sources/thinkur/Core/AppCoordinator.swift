import SwiftUI
import os

@MainActor
@Observable
final class AppCoordinator {
    let services: ServiceContainer
    private let viewModels: ViewModelFactory
    private let modelLoadCoordinator: ModelLoadCoordinator

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

    init() {
        let services = ServiceContainer()
        self.services = services
        self.viewModels = ViewModelFactory(services: services)
        self.modelLoadCoordinator = ModelLoadCoordinator(
            transcriptionEngine: services.transcriptionEngine,
            sharedState: services.sharedState,
            telemetryService: services.telemetryService
        )

        Task { [weak self] in
            await self?.setup()
        }
    }

    private func setup() async {
        guard !hasSetup else { return }
        hasSetup = true

        // Start model loading concurrently — runs alongside permission setup
        async let modelLoad: () = modelLoadCoordinator.loadModel()

        permissionManager.checkAll()

        if !permissionManager.microphoneGranted {
            await permissionManager.requestMicrophone()
            permissionManager.checkAll()
        }

        if !permissionManager.accessibilityGranted {
            permissionManager.requestAccessibility()
            permissionManager.checkAll()
        }

        services.telemetryService.initialize()
        services.frontmostAppDetector.startObserving()
        recordingViewModel.setupHotkey()

        await services.licenseManager.validateOnLaunch()
        await modelLoad
    }

    func updateHotkey() {
        services.hotkeyManager.targetKeyCode = settings.hotkeyCode
        services.hotkeyManager.targetModifiers = CGEventFlags(rawValue: UInt64(settings.hotkeyModifiers))
    }

    func clearAllHistory() async {
        try? await services.analyticsService.clearAllHistory()
        await homeViewModel.loadData()
        await insightsViewModel.loadData()
    }
}
