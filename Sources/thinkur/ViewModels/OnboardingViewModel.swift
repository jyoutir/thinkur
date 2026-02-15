import Foundation
import SwiftUI

@MainActor
@Observable
final class OnboardingViewModel {
    var currentStep: Int = 0
    private let totalSteps = 6

    var isComplete: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    private let permissionViewModel: PermissionViewModel

    init(permissionViewModel: PermissionViewModel) {
        self.permissionViewModel = permissionViewModel
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
        await permissionViewModel.requestMicrophone()
        nextStep()
    }

    func openAccessibilitySettings() {
        permissionViewModel.openAccessibilitySettings()
        nextStep()
    }

    func openInputMonitoringSettings() {
        permissionViewModel.openInputMonitoringSettings()
        nextStep()
    }

    private func completeOnboarding() {
        isComplete = true
    }
}
