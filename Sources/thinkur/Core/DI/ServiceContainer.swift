import Foundation

@MainActor
final class ServiceContainer {
    let settings: SettingsManager
    let sharedState: SharedAppState
    let permissionManager: PermissionManager
    let transcriptionEngine: TranscriptionEngine
    let audioCaptureManager: AudioCaptureManager
    let hotkeyManager: HotkeyManager
    let textInsertionService: TextInsertionService
    let frontmostAppDetector: FrontmostAppDetector
    let amplitudeProvider: AudioAmplitudeProvider
    let analyticsService: AnalyticsService
    let shortcutService: ShortcutService
    let stylePreferenceService: StylePreferenceService
    let textPostProcessor: TextPostProcessor

    init() {
        self.settings = .shared
        self.sharedState = SharedAppState()
        self.permissionManager = PermissionManager()
        self.transcriptionEngine = TranscriptionEngine()
        self.audioCaptureManager = AudioCaptureManager()
        self.hotkeyManager = HotkeyManager()
        self.textInsertionService = TextInsertionService()
        self.frontmostAppDetector = FrontmostAppDetector()
        self.amplitudeProvider = AudioAmplitudeProvider()
        self.analyticsService = AnalyticsService()
        self.shortcutService = ShortcutService()
        self.stylePreferenceService = StylePreferenceService()
        self.textPostProcessor = TextPostProcessor(processors: [
            SelfCorrectionProcessor(),
            FillerRemovalProcessor(),
            SpokenPunctuationProcessor(),
            NumberConversionProcessor(),
            PausePunctuationProcessor(),
            CapitalizationProcessor(),
            StyleAdaptationProcessor(),
        ])
    }

    /// Testing initializer — accepts pre-built services
    init(
        settings: SettingsManager,
        sharedState: SharedAppState,
        permissionManager: PermissionManager,
        transcriptionEngine: TranscriptionEngine,
        audioCaptureManager: AudioCaptureManager,
        hotkeyManager: HotkeyManager,
        textInsertionService: TextInsertionService,
        frontmostAppDetector: FrontmostAppDetector,
        amplitudeProvider: AudioAmplitudeProvider,
        analyticsService: AnalyticsService,
        shortcutService: ShortcutService,
        stylePreferenceService: StylePreferenceService,
        textPostProcessor: TextPostProcessor
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
    }
}
