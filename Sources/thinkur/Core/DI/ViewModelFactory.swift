import Foundation

@MainActor
final class ViewModelFactory {
    let recordingCoordinator: RecordingCoordinator
    let recordingViewModel: RecordingViewModel
    let homeViewModel: HomeViewModel
    let shortcutsViewModel: ShortcutsViewModel
    let styleViewModel: StyleViewModel
    let insightsViewModel: InsightsViewModel
    let onboardingViewModel: OnboardingViewModel
    let integrationsViewModel: IntegrationsViewModel

    init(services: ServiceContainer) {
        self.recordingCoordinator = RecordingCoordinator(
            audioCaptureManager: services.audioCaptureManager,
            transcriptionEngine: services.transcriptionEngine,
            textInsertionService: services.textInsertionService,
            textPostProcessor: services.textPostProcessor,
            frontmostAppDetector: services.frontmostAppDetector,
            analyticsService: services.analyticsService,
            amplitudeProvider: services.amplitudeProvider,
            settings: services.settings,
            sharedState: services.sharedState,
            shortcutService: services.shortcutService,
            smartHomeService: services.smartHomeService
        )
        self.recordingViewModel = RecordingViewModel(
            coordinator: self.recordingCoordinator,
            hotkeyManager: services.hotkeyManager,
            settings: services.settings,
            sharedState: services.sharedState
        )
        self.homeViewModel = HomeViewModel(analyticsService: services.analyticsService, sharedState: services.sharedState)
        self.shortcutsViewModel = ShortcutsViewModel(shortcutService: services.shortcutService)
        self.styleViewModel = StyleViewModel(stylePreferenceService: services.stylePreferenceService)
        self.insightsViewModel = InsightsViewModel(analyticsService: services.analyticsService)
        self.onboardingViewModel = OnboardingViewModel(permissionManager: services.permissionManager, settings: services.settings)
        self.integrationsViewModel = IntegrationsViewModel(smartHomeService: services.smartHomeService)
    }
}
