import Testing
import Foundation
import SwiftData
@testable import thinkur

@Suite("RecordingViewModel", .serialized)
struct RecordingViewModelTests {
    @MainActor
    private func makeDeps() -> (
        audio: MockAudioCapturing,
        transcription: MockTranscribing,
        textInserter: MockTextInserting,
        hotkey: MockHotkeyListening,
        state: SharedAppState,
        vm: RecordingViewModel
    ) {
        let audio = MockAudioCapturing()
        let transcription = MockTranscribing()
        let textInserter = MockTextInserting()
        let hotkey = MockHotkeyListening()
        let frontmost = FrontmostAppDetector()
        let amplitude = AudioAmplitudeProvider()
        let sharedState = SharedAppState()

        let schema = Schema([TranscriptionRecord.self, AppUsageRecord.self, DailyAnalytics.self])
        let container = SwiftDataContainerFactory.createInMemory(schema: schema)
        let analytics = AnalyticsService(container: container)

        let suiteName = "com.thinkur.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let settings = SettingsManager(defaults: defaults)

        let postProcessor = TextPostProcessor(processors: [])

        let vm = RecordingViewModel(
            audioCaptureManager: audio,
            transcriptionEngine: transcription,
            textInsertionService: textInserter,
            textPostProcessor: postProcessor,
            frontmostAppDetector: frontmost,
            analyticsService: analytics,
            amplitudeProvider: amplitude,
            hotkeyManager: hotkey,
            settings: settings,
            sharedState: sharedState,
            createFloatingPanel: false
        )

        return (audio, transcription, textInserter, hotkey, sharedState, vm)
    }

    @Test @MainActor func initialStateIsIdle() {
        let deps = makeDeps()
        #expect(deps.vm.state == .idle)
    }

    @Test @MainActor func setupHotkeyStartsManager() {
        let deps = makeDeps()
        deps.vm.setupHotkey()
        #expect(deps.hotkey.isRunning)
        #expect(deps.hotkey.onKeyDown != nil)
    }

    @Test @MainActor func toggleFromIdleToListening() async {
        let deps = makeDeps()
        deps.vm.setupHotkey()
        deps.hotkey.onKeyDown?()
        // onKeyDown wraps in a Task — yield to let it run
        try? await Task.sleep(for: .milliseconds(50))
        #expect(deps.vm.state == .listening)
    }

    @Test @MainActor func stateUpdatesPropagatesToSharedState() async {
        let deps = makeDeps()
        deps.vm.setupHotkey()
        deps.hotkey.onKeyDown?()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(deps.state.appState == .listening)
    }

    @Test @MainActor func shortRecordingSkipped() async {
        let deps = makeDeps()
        deps.vm.setupHotkey()
        // Start listening
        deps.hotkey.onKeyDown?()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(deps.vm.state == .listening)

        // Return very few samples (< 0.3 seconds at 16000 Hz)
        deps.audio.samplesToReturn = Array(repeating: Float(0.1), count: 100)

        // Stop listening
        deps.hotkey.onKeyDown?()
        try? await Task.sleep(for: .milliseconds(200))
        #expect(deps.vm.state == .idle)
        #expect(deps.textInserter.insertedTexts.isEmpty)
    }

    @Test @MainActor func successfulTranscription() async {
        let deps = makeDeps()
        deps.vm.setupHotkey()

        // Start listening
        deps.hotkey.onKeyDown?()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(deps.vm.state == .listening)

        // Return enough samples (> 0.3 seconds at 16000 Hz)
        deps.audio.samplesToReturn = Array(repeating: Float(0.1), count: 8000)
        deps.transcription.transcriptionResult = "hello world"

        // Stop listening
        deps.hotkey.onKeyDown?()
        try? await Task.sleep(for: .milliseconds(300))
        #expect(deps.vm.state == .idle)
        #expect(deps.textInserter.insertedTexts == ["hello world"])
        #expect(deps.state.lastTranscription == "hello world")
    }
}
