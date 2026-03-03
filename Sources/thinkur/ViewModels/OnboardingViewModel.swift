import Foundation
import SwiftUI

@MainActor
@Observable
final class OnboardingViewModel {
    var currentStep: Int = 0
    private let totalSteps = 5

    var isComplete: Bool {
        get { settings.hasCompletedOnboarding }
        set { settings.hasCompletedOnboarding = newValue }
    }

    private let permissionManager: PermissionManager
    private let settings: SettingsManager
    private let sharedState: SharedAppState
    let licenseManager: LicenseManager
    private let telemetryService: TelemetryService
    private var pollingTimer: Timer?
    private var stepEnteredAt: Date?
    private var onboardingStartedAt: Date?

    init(permissionManager: PermissionManager, settings: SettingsManager, sharedState: SharedAppState, licenseManager: LicenseManager, telemetryService: TelemetryService) {
        self.permissionManager = permissionManager
        self.settings = settings
        self.sharedState = sharedState
        self.licenseManager = licenseManager
        self.telemetryService = telemetryService
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
        case 4: return licenseManager.isLicensed
        default: return true
        }
    }

    func nextStep() {
        if currentStep == 0 && isComplete {
            // Returning user just needed to re-grant permissions — skip remaining steps
            return
        }

        let stepNames = ["Permissions", "Model", "QuickSettings", "TryIt", "Activate"]
        let durationOnStep = Int(Date().timeIntervalSince(stepEnteredAt ?? Date()))
        telemetryService.trackOnboardingStep(
            step: currentStep,
            stepName: stepNames[currentStep],
            durationOnStepSeconds: durationOnStep
        )

        if currentStep < totalSteps - 1 {
            currentStep += 1
            stepEnteredAt = Date()
        } else {
            let totalDuration = Int(Date().timeIntervalSince(onboardingStartedAt ?? Date()))
            telemetryService.trackOnboardingCompleted(totalDurationSeconds: totalDuration)
            completeOnboarding()
        }
    }

    func trackOnboardingStarted() {
        onboardingStartedAt = Date()
        stepEnteredAt = Date()
    }

    func previousStep() {
        if currentStep > 0 {
            currentStep -= 1
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

    var modelDownloadProgress: Double {
        sharedState.modelDownloadProgress
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

    func grantNextPermission() async {
        if !permissionManager.microphoneGranted {
            await requestMicrophone()
        } else if !permissionManager.accessibilityGranted {
            permissionManager.requestAccessibility()
        } else if !permissionManager.inputMonitoringGranted {
            permissionManager.requestInputMonitoring()
            permissionManager.openInputMonitoringSettings()
        }
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
