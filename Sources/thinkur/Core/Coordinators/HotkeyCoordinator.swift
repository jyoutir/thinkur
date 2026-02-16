import Foundation
import os

@MainActor
final class HotkeyCoordinator {
    private let recordingViewModel: RecordingViewModel

    init(recordingViewModel: RecordingViewModel) {
        self.recordingViewModel = recordingViewModel
    }

    func setup() {
        recordingViewModel.setupHotkey()
    }
}
