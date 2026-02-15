import SwiftUI
import os

@MainActor
final class AppCoordinator: ObservableObject {
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

    // ViewModels (exposed to views)
    let menuBarViewModel: MenuBarViewModel
    let permissionViewModel: PermissionViewModel
    let recordingViewModel: RecordingViewModel
    let transcriptionViewModel: TranscriptionViewModel

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

        // Pre-warm audio engine for faster first recording
        audioCaptureManager.prepareEngine()

        // Start hotkey manager
        recordingViewModel.setupHotkey()

        // Load WhisperKit model
        menuBarViewModel.appState = .loading
        transcriptionViewModel.syncState()
        await transcriptionEngine.loadModel()
        transcriptionViewModel.syncState()

        if transcriptionEngine.isLoaded {
            menuBarViewModel.appState = .idle
            recordingViewModel.isModelReady = true
            Logger.app.info("thinkur ready")
        } else {
            menuBarViewModel.appState = .error("Model failed to load")
            Logger.app.error("Failed to load transcription model")
        }
    }
}
