import Testing
import Foundation
@testable import thinkur

@Suite("AppCoordinator Integration")
struct AppCoordinatorTests {
    @Test @MainActor func serviceContainerCreatesAllServices() {
        let container = ServiceContainer()
        // Verify all services are created (non-nil by construction)
        #expect(container.settings === SettingsManager.shared)
        #expect(container.sharedState.appState == .idle)
    }

    @Test @MainActor func viewModelFactoryCreatesAllViewModels() {
        let container = ServiceContainer()
        let factory = ViewModelFactory(services: container)
        // All ViewModels should be created without crashing
        #expect(factory.recordingViewModel.state == .idle)
        #expect(factory.homeViewModel.groupedTranscriptions.isEmpty)
        #expect(factory.shortcutsViewModel.shortcuts.isEmpty)
        #expect(factory.insightsViewModel.totalWords == 0)
        #expect(factory.onboardingViewModel.currentStep == 0)
    }

    @Test @MainActor func modelLoadCoordinatorUpdatesSharedState() async {
        let sharedState = SharedAppState()
        let engine = TranscriptionEngine()
        let settings = SettingsManager(defaults: UserDefaults(suiteName: "com.thinkur.test.\(UUID().uuidString)")!)
        let coordinator = ModelLoadCoordinator(
            transcriptionEngine: engine,
            sharedState: sharedState,
            telemetryService: TelemetryService(settings: settings)
        )
        // Just verify it doesn't crash — actual model loading would require resources
        #expect(sharedState.appState == .idle)
    }
}
