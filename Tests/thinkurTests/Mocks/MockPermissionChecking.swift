import Foundation
@testable import thinkur

@MainActor
final class MockPermissionChecking: PermissionChecking {
    var accessibilityGranted = true
    var microphoneGranted = true
    var screenRecordingGranted = true

    var allGranted: Bool {
        accessibilityGranted && microphoneGranted
    }

    func checkAll() {}
    func checkMicrophone() {}
    func checkScreenRecording() {}
    func requestAccessibility() {}
    func requestMicrophone() async {}
    func requestScreenRecording() {}
    func openAccessibilitySettings() {}
    func openScreenRecordingSettings() {}
}
