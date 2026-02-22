import AVFoundation
import Cocoa
import os

@MainActor
@Observable
final class PermissionManager: PermissionChecking {
    var accessibilityGranted = false
    var microphoneGranted = false
    var inputMonitoringGranted = false

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
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Microphone

    func checkMicrophone() {
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    func requestMicrophone() async {
        let alreadyDetermined = AVCaptureDevice.authorizationStatus(for: .audio) != .notDetermined
        if alreadyDetermined {
            // User already denied — re-requesting won't show a dialog, open Settings instead
            openMicrophoneSettings()
            return
        }
        microphoneGranted = await AVCaptureDevice.requestAccess(for: .audio)
        if !microphoneGranted {
            openMicrophoneSettings()
        }
    }

    // MARK: - Input Monitoring

    func checkInputMonitoring() {
        inputMonitoringGranted = CGPreflightListenEventAccess()
    }

    func requestInputMonitoring() {
        CGRequestListenEventAccess()
        Logger.permissions.info("Requested Input Monitoring access — user must enable in System Settings")
    }

    // MARK: - Open System Settings

    func openMicrophoneSettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        )
    }

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
