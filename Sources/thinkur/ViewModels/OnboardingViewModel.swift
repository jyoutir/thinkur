import Foundation
import SwiftUI

@MainActor
@Observable
final class OnboardingViewModel {
    var currentStep: Int = 0
    private let totalSteps = 6

    var isComplete: Bool {
        get { settings.hasCompletedOnboarding }
        set { settings.hasCompletedOnboarding = newValue }
    }

    private let permissionManager: PermissionManager
    private let settings: SettingsManager

    init(permissionManager: PermissionManager, settings: SettingsManager) {
        self.permissionManager = permissionManager
        self.settings = settings
    }

    var isLastStep: Bool {
        currentStep >= totalSteps - 1
    }

    var progress: Double {
        Double(currentStep + 1) / Double(totalSteps)
    }

    func nextStep() {
        if currentStep < totalSteps - 1 {
            currentStep += 1
        } else {
            completeOnboarding()
        }
    }

    func skip() {
        completeOnboarding()
    }

    func requestMicrophone() async {
        await permissionManager.requestMicrophone()
        nextStep()
    }

    func openAccessibilitySettings() {
        permissionManager.openAccessibilitySettings()
        nextStep()
    }

    func openInputMonitoringSettings() {
        permissionManager.openInputMonitoringSettings()
        nextStep()
    }

    private func completeOnboarding() {
        isComplete = true
    }
}
