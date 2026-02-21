import Foundation
import SwiftUI

@MainActor
@Observable
final class OnboardingViewModel {
    var currentStep: Int = 0
    private let totalSteps = 4

    var isComplete: Bool {
        get { settings.hasCompletedOnboarding }
        set { settings.hasCompletedOnboarding = newValue }
    }

    private let permissionManager: PermissionManager
    private let settings: SettingsManager
    private let sharedState: SharedAppState
    private var pollingTimer: Timer?

    init(permissionManager: PermissionManager, settings: SettingsManager, sharedState: SharedAppState) {
        self.permissionManager = permissionManager
        self.settings = settings
        self.sharedState = sharedState
    }

    // MARK: - Navigation

    var isLastStep: Bool {
        currentStep >= totalSteps - 1
    }

    var progress: Double {
        Double(currentStep + 1) / Double(totalSteps)
    }

    var canContinue: Bool {
        switch currentStep {
        case 0: return allPermissionsGranted
        case 1: return isModelReady
        default: return true
        }
    }

    func nextStep() {
        if currentStep < totalSteps - 1 {
            currentStep += 1
        } else {
            completeOnboarding()
        }
    }

    // MARK: - Model State

    var isModelReady: Bool {
        sharedState.isModelReady
    }

    var isModelLoading: Bool {
        sharedState.isModelLoading
    }

    var modelLoadingMessage: String {
        sharedState.modelLoadingMessage
    }

    // MARK: - Permissions

    var allPermissionsGranted: Bool {
        permissionManager.allGranted
    }

    func requestMicrophone() async {
        await permissionManager.requestMicrophone()
    }

    func openAccessibilitySettings() {
        permissionManager.openAccessibilitySettings()
    }

    func openInputMonitoringSettings() {
        permissionManager.openInputMonitoringSettings()
    }

    // MARK: - Permission Polling

    func startPermissionPolling() {
        stopPermissionPolling()
        permissionManager.checkAll()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.permissionManager.checkAll()
            }
        }
    }

    func stopPermissionPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    // MARK: - Completion

    func completeSetup() {
        completeOnboarding()
    }

    private func completeOnboarding() {
        stopPermissionPolling()
        isComplete = true
    }
}
