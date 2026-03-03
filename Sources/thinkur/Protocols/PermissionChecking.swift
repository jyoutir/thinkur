import Foundation

@MainActor
protocol PermissionChecking: AnyObject {
    var accessibilityGranted: Bool { get }
    var microphoneGranted: Bool { get }
    var allGranted: Bool { get }
    var screenRecordingGranted: Bool { get }
    func checkAll()
    func checkMicrophone()
    func checkScreenRecording()
    func requestAccessibility()
    func requestMicrophone() async
    func requestScreenRecording()
    func openAccessibilitySettings()
    func openScreenRecordingSettings()
}
