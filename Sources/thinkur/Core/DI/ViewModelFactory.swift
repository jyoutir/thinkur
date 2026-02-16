import Foundation

@MainActor
final class ViewModelFactory {
    let menuBarViewModel: MenuBarViewModel
    let recordingViewModel: RecordingViewModel
    let homeViewModel: HomeViewModel
    let shortcutsViewModel: ShortcutsViewModel
    let styleViewModel: StyleViewModel
    let insightsViewModel: InsightsViewModel
    let onboardingViewModel: OnboardingViewModel

    init(services: ServiceContainer) {
        self.menuBarViewModel = MenuBarViewModel(
            frontmostAppDetector: services.frontmostAppDetector,
            sharedState: services.sharedState
        )
        self.recordingViewModel = RecordingViewModel(
            audioCaptureManager: services.audioCaptureManager,
            transcriptionEngine: services.transcriptionEngine,
            textInsertionService: services.textInsertionService,
            textPostProcessor: services.textPostProcessor,
            frontmostAppDetector: services.frontmostAppDetector,
            analyticsService: services.analyticsService,
            amplitudeProvider: services.amplitudeProvider,
            hotkeyManager: services.hotkeyManager,
            settings: services.settings,
            sharedState: services.sharedState
        )
        self.homeViewModel = HomeViewModel(analyticsService: services.analyticsService)
        self.shortcutsViewModel = ShortcutsViewModel(shortcutService: services.shortcutService)
        self.styleViewModel = StyleViewModel(stylePreferenceService: services.stylePreferenceService)
        self.insightsViewModel = InsightsViewModel(analyticsService: services.analyticsService)
        self.onboardingViewModel = OnboardingViewModel(permissionManager: services.permissionManager)
    }
}
