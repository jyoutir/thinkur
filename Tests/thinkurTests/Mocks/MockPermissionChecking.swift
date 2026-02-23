import Foundation
@testable import thinkur

@MainActor
final class MockPermissionChecking: PermissionChecking {
    var accessibilityGranted = true
    var microphoneGranted = true
    var inputMonitoringGranted = true

    var allGranted: Bool {
        accessibilityGranted && microphoneGranted && inputMonitoringGranted
    }

    func checkAll() {}
    func checkMicrophone() {}
    func requestAccessibility() {}
    func requestMicrophone() async {}
    func requestInputMonitoring() {}
    func openAccessibilitySettings() {}
    func openInputMonitoringSettings() {}
}
