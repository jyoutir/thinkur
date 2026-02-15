import SwiftUI
import os

@MainActor
@Observable
final class AppCoordinator {
    // Services (private — views never touch these)
    private let permissionManager: PermissionManager
    private let transcriptionEngine: TranscriptionEngine
    private let audioCaptureManager: AudioCaptureManager
    private let hotkeyManager: HotkeyManager
    private let textInsertionService: TextInsertionService
    private let textPostProcessor: TextPostProcessor
    private let frontmostAppDetector: FrontmostAppDetector
    private let amplitudeProvider: AudioAmplitudeProvider
    private let analyticsService: AnalyticsService
    private let shortcutService: ShortcutService
    private let stylePreferenceService: StylePreferenceService

    // ViewModels (exposed to views)
    let menuBarViewModel: MenuBarViewModel
    let permissionViewModel: PermissionViewModel
    let recordingViewModel: RecordingViewModel
    let transcriptionViewModel: TranscriptionViewModel
    let homeViewModel: HomeViewModel
    let shortcutsViewModel: ShortcutsViewModel
    let styleViewModel: StyleViewModel
    let insightsViewModel: InsightsViewModel
    let onboardingViewModel: OnboardingViewModel

    private var hasSetup = false

    init() {
        // 1. Create services
        let permissions = PermissionManager()
        let transcription = TranscriptionEngine()
        let audio = AudioCaptureManager()
        let hotkey = HotkeyManager()
        let textInsertion = TextInsertionService()
        let frontmost = FrontmostAppDetector()
        let amplitude = AudioAmplitudeProvider()
        let analytics = AnalyticsService()
        let shortcuts = ShortcutService()
        let stylePrefs = StylePreferenceService()

        let postProcessor = TextPostProcessor(processors: [
            SelfCorrectionProcessor(),
            FillerRemovalProcessor(),
            SpokenPunctuationProcessor(),
            NumberConversionProcessor(),
            PausePunctuationProcessor(),
            CapitalizationProcessor(),
            StyleAdaptationProcessor(),
        ])

        self.permissionManager = permissions
        self.transcriptionEngine = transcription
        self.audioCaptureManager = audio
        self.hotkeyManager = hotkey
        self.textInsertionService = textInsertion
        self.textPostProcessor = postProcessor
        self.frontmostAppDetector = frontmost
        self.amplitudeProvider = amplitude
        self.analyticsService = analytics
        self.shortcutService = shortcuts
        self.stylePreferenceService = stylePrefs

        // 2. Create ViewModels with injected dependencies
        let menuBarVM = MenuBarViewModel(frontmostAppDetector: frontmost)
        let permissionVM = PermissionViewModel(permissionManager: permissions)
        let recordingVM = RecordingViewModel(
            audioCaptureManager: audio,
            transcriptionEngine: transcription,
            textInsertionService: textInsertion,
            textPostProcessor: postProcessor,
            frontmostAppDetector: frontmost,
            analyticsService: analytics,
            amplitudeProvider: amplitude,
            hotkeyManager: hotkey
        )
        let transcriptionVM = TranscriptionViewModel(transcriptionEngine: transcription)

        self.menuBarViewModel = menuBarVM
        self.permissionViewModel = permissionVM
        self.recordingViewModel = recordingVM
        self.transcriptionViewModel = transcriptionVM
        self.homeViewModel = HomeViewModel(analyticsService: analytics)
        self.shortcutsViewModel = ShortcutsViewModel(shortcutService: shortcuts)
        self.styleViewModel = StyleViewModel(stylePreferenceService: stylePrefs)
        self.insightsViewModel = InsightsViewModel(analyticsService: analytics)
        self.onboardingViewModel = OnboardingViewModel(permissionViewModel: permissionVM)

        // 3. Wire cross-cutting callbacks
        recordingVM.onStateChanged = { [weak menuBarVM] newState in
            menuBarVM?.appState = newState
        }
        recordingVM.onTranscription = { [weak menuBarVM] text in
            menuBarVM?.lastTranscription = text
        }

        // 4. Kick off async setup
        Task { [weak self] in
            await self?.setup()
        }
    }

    private func setup() async {
        guard !hasSetup else { return }
        hasSetup = true

        // Check permissions
        permissionViewModel.checkPermissions()

        if !permissionManager.microphoneGranted {
            await permissionManager.requestMicrophone()
            permissionViewModel.checkPermissions()
        }

        if !permissionManager.accessibilityGranted {
            permissionManager.requestAccessibility()
            permissionViewModel.checkPermissions()
        }

        // Start frontmost app detection
        frontmostAppDetector.startObserving()

        // Start hotkey manager
        recordingViewModel.setupHotkey()

        // Load WhisperKit model
        await loadModelAndUpdateState()
    }

    private func loadModelAndUpdateState() async {
        menuBarViewModel.appState = .loading
        await transcriptionEngine.loadModel()

        if transcriptionEngine.isLoaded {
            menuBarViewModel.appState = .idle
            recordingViewModel.isModelReady = true
            Logger.app.info("thinkur ready")
        } else {
            let message = transcriptionEngine.errorMessage ?? "Model failed to load"
            menuBarViewModel.appState = .error(message)
            Logger.app.error("Failed to load transcription model: \(message)")
        }
    }

    func retryModelLoad() async {
        await loadModelAndUpdateState()
    }
}
