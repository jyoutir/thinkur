import Foundation

@MainActor
protocol PermissionChecking: AnyObject {
    var accessibilityGranted: Bool { get }
    var microphoneGranted: Bool { get }
    var inputMonitoringGranted: Bool { get }
    var allGranted: Bool { get }
    func checkAll()
    func requestAccessibility()
    func requestMicrophone() async
    func requestInputMonitoring()
    func openAccessibilitySettings()
    func openInputMonitoringSettings()
}
