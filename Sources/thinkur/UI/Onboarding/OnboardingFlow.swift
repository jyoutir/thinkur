import SwiftUI

struct OnboardingFlow: View {
    @Environment(OnboardingViewModel.self) private var viewModel

    private let steps = OnboardingSteps.all

    var body: some View {
        ZStack {
            // Background
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        viewModel.skip()
                    }
                    .buttonStyle(.plain)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .padding(Spacing.md)
                }

                // Step content
                if viewModel.currentStep < steps.count {
                    let step = steps[viewModel.currentStep]

                    OnboardingStepView(step: step) {
                        handleAction(step.action)
                    }
                    .id(viewModel.currentStep)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .animation(Animations.onboardingEntrance, value: viewModel.currentStep)
                }

                // Page dots
                HStack(spacing: Spacing.xs) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Capsule()
                            .fill(index == viewModel.currentStep ? ColorTokens.textPrimary : ColorTokens.border)
                            .frame(width: index == viewModel.currentStep ? 24 : 8, height: 8)
                            .animation(Animations.springBounce, value: viewModel.currentStep)
                    }
                }
                .padding(.bottom, Spacing.lg)
            }
        }
        .frame(minWidth: 920, minHeight: 620)
    }

    private func handleAction(_ action: OnboardingStepData.StepAction) {
        switch action {
        case .next:
            viewModel.nextStep()
        case .requestMicrophone:
            Task { await viewModel.requestMicrophone() }
        case .openAccessibility:
            viewModel.openAccessibilitySettings()
        case .openInputMonitoring:
            viewModel.openInputMonitoringSettings()
        }
    }
}
