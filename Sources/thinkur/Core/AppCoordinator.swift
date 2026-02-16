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

    var recordingViewModel: RecordingViewModel { viewModels.recordingViewModel }
    var homeViewModel: HomeViewModel { viewModels.homeViewModel }
    var shortcutsViewModel: ShortcutsViewModel { viewModels.shortcutsViewModel }
    var styleViewModel: StyleViewModel { viewModels.styleViewModel }
    var insightsViewModel: InsightsViewModel { viewModels.insightsViewModel }
    var onboardingViewModel: OnboardingViewModel { viewModels.onboardingViewModel }

    init() {
        let services = ServiceContainer()
        self.services = services
        self.viewModels = ViewModelFactory(services: services)
        self.modelLoadCoordinator = ModelLoadCoordinator(
            transcriptionEngine: services.transcriptionEngine,
            sharedState: services.sharedState
        )

        Task { [weak self] in
            await self?.setup()
        }
    }

    private func setup() async {
        guard !hasSetup else { return }
        hasSetup = true

        permissionManager.checkAll()

        if !permissionManager.microphoneGranted {
            await permissionManager.requestMicrophone()
            permissionManager.checkAll()
        }

        if !permissionManager.accessibilityGranted {
            permissionManager.requestAccessibility()
            permissionManager.checkAll()
        }

        services.frontmostAppDetector.startObserving()
        recordingViewModel.setupHotkey()

        await modelLoadCoordinator.loadModel()
    }

    func retryModelLoad() async {
        await modelLoadCoordinator.loadModel()
    }

    func clearAllHistory() async {
        try? await services.analyticsService.clearAllHistory()
        await homeViewModel.loadData()
        await insightsViewModel.loadData()
    }
}
