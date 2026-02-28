import Foundation

@MainActor
final class ServiceContainer {
    let settings: SettingsManager
    let sharedState: SharedAppState
    let permissionManager: PermissionManager
    let transcriptionEngine: ParakeetTranscriptionEngine
    let audioCaptureManager: AudioCaptureManager
    let hotkeyManager: HotkeyManager
    let textInsertionService: TextInsertionService
    let frontmostAppDetector: FrontmostAppDetector
    let amplitudeProvider: AudioAmplitudeProvider
    let analyticsService: AnalyticsService
    let shortcutService: ShortcutService
    let stylePreferenceService: StylePreferenceService
    let textPostProcessor: TextPostProcessor
    let smartHomeService: SmartHomeService
    let licenseManager: LicenseManager
    let telemetryService: TelemetryService
    let meetingService: MeetingService
    let speakerProfileService: SpeakerProfileService

    init() {
        self.settings = .shared
        self.sharedState = SharedAppState()
        self.permissionManager = PermissionManager()
        self.transcriptionEngine = ParakeetTranscriptionEngine()
        self.audioCaptureManager = AudioCaptureManager()
        self.hotkeyManager = HotkeyManager()
        self.textInsertionService = TextInsertionService()
        self.frontmostAppDetector = FrontmostAppDetector()
        self.amplitudeProvider = AudioAmplitudeProvider()
        self.analyticsService = AnalyticsService()
        self.shortcutService = ShortcutService()
        self.smartHomeService = SmartHomeService()
        self.licenseManager = LicenseManager()
        self.telemetryService = TelemetryService(settings: self.settings)
        self.meetingService = MeetingService()
        self.speakerProfileService = SpeakerProfileService()
        self.licenseManager.telemetryService = self.telemetryService
        self.stylePreferenceService = StylePreferenceService()
        self.textPostProcessor = TextPostProcessor(processors: [
            SelfCorrectionProcessor(),
            FillerRemovalProcessor(),
            SmartFormattingProcessor(),
            StyleAdaptationProcessor(),
            ListDetectionProcessor(),
            CodeContextProcessor(),
        ])
    }

    /// Testing initializer — accepts pre-built services
    init(
        settings: SettingsManager,
        sharedState: SharedAppState,
        permissionManager: PermissionManager,
        transcriptionEngine: ParakeetTranscriptionEngine,
        audioCaptureManager: AudioCaptureManager,
        hotkeyManager: HotkeyManager,
        textInsertionService: TextInsertionService,
        frontmostAppDetector: FrontmostAppDetector,
        amplitudeProvider: AudioAmplitudeProvider,
        analyticsService: AnalyticsService,
        shortcutService: ShortcutService,
        stylePreferenceService: StylePreferenceService,
        textPostProcessor: TextPostProcessor,
        smartHomeService: SmartHomeService,
        licenseManager: LicenseManager,
        telemetryService: TelemetryService,
        meetingService: MeetingService,
        speakerProfileService: SpeakerProfileService
    ) {
        self.settings = settings
        self.sharedState = sharedState
        self.permissionManager = permissionManager
        self.transcriptionEngine = transcriptionEngine
        self.audioCaptureManager = audioCaptureManager
        self.hotkeyManager = hotkeyManager
        self.textInsertionService = textInsertionService
        self.frontmostAppDetector = frontmostAppDetector
        self.amplitudeProvider = amplitudeProvider
        self.analyticsService = analyticsService
        self.shortcutService = shortcutService
        self.stylePreferenceService = stylePreferenceService
        self.textPostProcessor = textPostProcessor
        self.smartHomeService = smartHomeService
        self.licenseManager = licenseManager
        self.telemetryService = telemetryService
        self.meetingService = meetingService
        self.speakerProfileService = speakerProfileService
    }
}
