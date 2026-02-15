import Foundation

struct OnboardingStepData {
    let emoji: String
    let title: String
    let description: String
    let bullets: [String]
    let ctaLabel: String
    let isPermissionStep: Bool

    enum StepAction {
        case next
        case requestMicrophone
        case openAccessibility
        case openInputMonitoring
    }

    let action: StepAction
}

enum OnboardingSteps {
    static let all: [OnboardingStepData] = [
        OnboardingStepData(
            emoji: "\u{1F512}",
            title: "Completely Private",
            description: "Your voice never leaves your Mac. Everything is processed locally.",
            bullets: [
                "Powered by WhisperKit on-device",
                "Zero network requests for transcription",
                "Works fully offline"
            ],
            ctaLabel: "Continue",
            isPermissionStep: false,
            action: .next
        ),
        OnboardingStepData(
            emoji: "\u{26A1}",
            title: "Incredibly Fast",
            description: "Real-time transcription powered by Apple Silicon.",
            bullets: [
                "Real-time streaming transcription",
                "Optimized for Neural Engine",
                "Smart formatting and punctuation"
            ],
            ctaLabel: "Continue",
            isPermissionStep: false,
            action: .next
        ),
        OnboardingStepData(
            emoji: "\u{1F48E}",
            title: "One Price Forever",
            description: "No subscriptions. No hidden fees. Just one simple purchase.",
            bullets: [
                "$29 one-time purchase",
                "All future updates included",
                "No recurring charges"
            ],
            ctaLabel: "Get Started",
            isPermissionStep: false,
            action: .next
        ),
        OnboardingStepData(
            emoji: "\u{1F3A4}",
            title: "Microphone Access",
            description: "thinkur needs access to your microphone to hear your voice and convert it to text.",
            bullets: [],
            ctaLabel: "Allow Microphone",
            isPermissionStep: true,
            action: .requestMicrophone
        ),
        OnboardingStepData(
            emoji: "\u{267F}",
            title: "Accessibility",
            description: "Accessibility access allows thinkur to insert transcribed text directly into any application.",
            bullets: [],
            ctaLabel: "Open Settings",
            isPermissionStep: true,
            action: .openAccessibility
        ),
        OnboardingStepData(
            emoji: "\u{2328}",
            title: "Input Monitoring",
            description: "Input monitoring lets thinkur detect when you press the hotkey to start and stop recording.",
            bullets: [],
            ctaLabel: "Open Settings",
            isPermissionStep: true,
            action: .openInputMonitoring
        ),
    ]
}
