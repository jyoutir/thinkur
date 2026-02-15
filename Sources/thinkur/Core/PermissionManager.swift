import AVFoundation
import Cocoa
import os

@MainActor
final class PermissionManager: ObservableObject {
    @Published var accessibilityGranted = false
    @Published var microphoneGranted = false
    @Published var inputMonitoringGranted = false

    var allGranted: Bool {
        accessibilityGranted && microphoneGranted && inputMonitoringGranted
    }

    func checkAll() {
        checkAccessibility()
        checkMicrophone()
        checkInputMonitoring()
    }

    // MARK: - Accessibility

    func checkAccessibility() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Microphone

    func checkMicrophone() {
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    func requestMicrophone() async {
        microphoneGranted = await AVCaptureDevice.requestAccess(for: .audio)
    }

    // MARK: - Input Monitoring

    func checkInputMonitoring() {
        inputMonitoringGranted = CGPreflightListenEventAccess()
    }

    func requestInputMonitoring() {
        CGRequestListenEventAccess()
        // This opens System Settings; user must grant manually
        Logger.permissions.info("Requested Input Monitoring access — user must enable in System Settings")
    }

    // MARK: - Open System Settings

    func openAccessibilitySettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
    }

    func openInputMonitoringSettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        )
    }
}
