import SwiftUI

struct OnboardingFlow: View {
    @Environment(OnboardingViewModel.self) private var viewModel

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

                // Page content
                Group {
                    switch viewModel.currentStep {
                    case 0:
                        PermissionsPage()
                    default:
                        ValueDemoPage()
                    }
                }
                .id(viewModel.currentStep)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(Animations.onboardingEntrance, value: viewModel.currentStep)

                // Page dots
                HStack(spacing: Spacing.xs) {
                    ForEach(0..<2, id: \.self) { index in
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
}
