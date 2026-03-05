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
    let meetingCoordinator: MeetingCoordinator
    let meetingViewModel: MeetingViewModel

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
            stylePreferenceService: services.stylePreferenceService,
            telemetryService: services.telemetryService,
            permissionManager: services.permissionManager,
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
        self.styleViewModel = StyleViewModel(stylePreferenceService: services.stylePreferenceService, analyticsService: services.analyticsService, settings: services.settings)
        self.insightsViewModel = InsightsViewModel(analyticsService: services.analyticsService)
        self.onboardingViewModel = OnboardingViewModel(permissionManager: services.permissionManager, settings: services.settings, sharedState: services.sharedState, telemetryService: services.telemetryService, licenseManager: services.licenseManager)
        self.integrationsViewModel = IntegrationsViewModel(smartHomeService: services.smartHomeService)
        self.meetingCoordinator = MeetingCoordinator(
            settings: services.settings,
            meetingService: services.meetingService,
            permissionManager: services.permissionManager,
            sharedState: services.sharedState
        )
        self.meetingViewModel = MeetingViewModel(
            coordinator: self.meetingCoordinator,
            meetingService: services.meetingService
        )
    }
}
