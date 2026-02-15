import Foundation

@MainActor
@Observable
final class PermissionViewModel {
    var accessibilityGranted = false
    var microphoneGranted = false
    var inputMonitoringGranted = false

    private let permissionManager: PermissionManager

    init(permissionManager: PermissionManager) {
        self.permissionManager = permissionManager
    }

    var allGranted: Bool {
        accessibilityGranted && microphoneGranted && inputMonitoringGranted
    }

    func checkPermissions() {
        permissionManager.checkAll()
        syncState()
    }

    func requestAccessibility() {
        permissionManager.requestAccessibility()
        syncState()
    }

    func requestMicrophone() async {
        await permissionManager.requestMicrophone()
        syncState()
    }

    func requestInputMonitoring() {
        permissionManager.requestInputMonitoring()
    }

    func openAccessibilitySettings() {
        permissionManager.openAccessibilitySettings()
    }

    func openInputMonitoringSettings() {
        permissionManager.openInputMonitoringSettings()
    }

    private func syncState() {
        accessibilityGranted = permissionManager.accessibilityGranted
        microphoneGranted = permissionManager.microphoneGranted
        inputMonitoringGranted = permissionManager.inputMonitoringGranted
    }
}
