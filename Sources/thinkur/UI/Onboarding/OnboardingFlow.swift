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
                Spacer()
                    .frame(height: Spacing.md)

                // Page content
                Group {
                    switch viewModel.currentStep {
                    case 0:
                        PermissionsPage()
                    case 1:
                        ModelLoadingPage()
                    case 2:
                        QuickSettingsPage()
                    default:
                        TryItPage()
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
                    ForEach(0..<4, id: \.self) { index in
                        Capsule()
                            .fill(index == viewModel.currentStep ? ColorTokens.textPrimary : ColorTokens.textTertiary)
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
