import Testing
import SwiftUI
@testable import thinkur

@Suite("MenuBarViewModel")
struct MenuBarViewModelTests {
    @MainActor
    private func makeVM(state: AppState = .idle) -> (SharedAppState, MenuBarViewModel) {
        let sharedState = SharedAppState()
        sharedState.appState = state
        let frontmost = FrontmostAppDetector()
        let vm = MenuBarViewModel(frontmostAppDetector: frontmost, sharedState: sharedState)
        return (sharedState, vm)
    }

    @Test @MainActor func idleIcon() {
        let (_, vm) = makeVM(state: .idle)
        #expect(vm.menuBarIcon == "mic")
    }

    @Test @MainActor func loadingIcon() {
        let (_, vm) = makeVM(state: .loading)
        #expect(vm.menuBarIcon == "arrow.down.circle")
    }

    @Test @MainActor func listeningIcon() {
        let (_, vm) = makeVM(state: .listening)
        #expect(vm.menuBarIcon == "mic.fill")
    }

    @Test @MainActor func processingIcon() {
        let (_, vm) = makeVM(state: .processing)
        #expect(vm.menuBarIcon == "ellipsis.circle")
    }

    @Test @MainActor func errorIcon() {
        let (_, vm) = makeVM(state: .error("test"))
        #expect(vm.menuBarIcon == "exclamationmark.triangle")
    }

    @Test @MainActor func idleStatusText() {
        let (_, vm) = makeVM(state: .idle)
        #expect(vm.statusText.contains("Ready"))
    }

    @Test @MainActor func listeningStatusText() {
        let (_, vm) = makeVM(state: .listening)
        #expect(vm.statusText.contains("Listening"))
    }

    @Test @MainActor func idleStatusColor() {
        let (_, vm) = makeVM(state: .idle)
        #expect(vm.statusColor == .green)
    }

    @Test @MainActor func listeningStatusColor() {
        let (_, vm) = makeVM(state: .listening)
        #expect(vm.statusColor == .red)
    }

    @Test @MainActor func readsFromSharedState() {
        let (sharedState, vm) = makeVM(state: .idle)
        #expect(vm.currentAppState == .idle)
        sharedState.appState = .listening
        #expect(vm.currentAppState == .listening)
    }

    @Test @MainActor func readsTranscriptionFromSharedState() {
        let (sharedState, vm) = makeVM()
        #expect(vm.currentTranscription == "")
        sharedState.lastTranscription = "test transcription"
        #expect(vm.currentTranscription == "test transcription")
    }
}
