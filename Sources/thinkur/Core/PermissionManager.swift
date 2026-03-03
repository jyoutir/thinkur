import AVFAudio
import Cocoa
import os
import ScreenCaptureKit

@MainActor
@Observable
final class PermissionManager: PermissionChecking {
    var accessibilityGranted = false
    var microphoneGranted = false
    var screenRecordingGranted = false

    var allGranted: Bool {
        accessibilityGranted && microphoneGranted
    }

    func checkAll() {
        checkAccessibility()
        checkMicrophone()
    }

    // MARK: - Accessibility

    func checkAccessibility() {
        let trusted = AXIsProcessTrusted()
        Logger.permissions.info("checkAccessibility: AXIsProcessTrusted = \(trusted)")
        accessibilityGranted = trusted
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
        Logger.permissions.info("requestAccessibility: AXIsProcessTrustedWithOptions returned \(self.accessibilityGranted)")
    }

    // MARK: - Microphone

    func checkMicrophone() {
        let status = AVAudioApplication.shared.recordPermission
        microphoneGranted = status == .granted
        Logger.permissions.info("checkMicrophone: recordPermission = \(status.rawValue, privacy: .public), granted = \(self.microphoneGranted)")
    }

    func requestMicrophone() async {
        let status = AVAudioApplication.shared.recordPermission
        Logger.permissions.info("requestMicrophone: current recordPermission = \(status.rawValue, privacy: .public)")
        if status != .undetermined {
            // User already decided — re-requesting won't show a dialog, open Settings instead
            Logger.permissions.info("requestMicrophone: permission already determined, opening Settings")
            openMicrophoneSettings()
            return
        }
        microphoneGranted = await AVAudioApplication.requestRecordPermission()
        Logger.permissions.info("requestMicrophone: after request, granted = \(self.microphoneGranted)")
        if !microphoneGranted {
            openMicrophoneSettings()
        }
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

    // MARK: - Screen Recording

    private var isCheckingScreenRecording = false

    func checkScreenRecording() {
        // Fast path: CGPreflight works when it works
        if CGPreflightScreenCaptureAccess() {
            screenRecordingGranted = true
            return
        }
        // CGPreflightScreenCaptureAccess is unreliable on macOS Sequoia
        // (returns false even when granted). Verify with ScreenCaptureKit.
        guard !isCheckingScreenRecording else { return }
        isCheckingScreenRecording = true
        Task {
            defer { isCheckingScreenRecording = false }
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                screenRecordingGranted = true
                Logger.permissions.info("checkScreenRecording: SCShareableContent succeeded, granted = true")
            } catch {
                screenRecordingGranted = false
                Logger.permissions.info("checkScreenRecording: SCShareableContent failed, granted = false")
            }
        }
    }

    func requestScreenRecording() {
        CGRequestScreenCaptureAccess()
        Logger.permissions.info("Requested Screen Recording access")
    }

    func openScreenRecordingSettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        )
    }

}
