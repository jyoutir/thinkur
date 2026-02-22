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
                    case 3:
                        TryItPage()
                    default:
                        LicenseActivationPage()
                    }
                }
                .id(viewModel.currentStep)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(Animations.onboardingEntrance, value: viewModel.currentStep)

                // Back button + Page dots
                HStack {
                    Button {
                        withAnimation(Animations.onboardingEntrance) {
                            viewModel.previousStep()
                        }
                    } label: {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Back")
                                .font(Typography.caption)
                        }
                        .foregroundStyle(ColorTokens.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .opacity(viewModel.currentStep > 0 ? 1 : 0)
                    .disabled(viewModel.currentStep == 0)

                    Spacer()

                    HStack(spacing: Spacing.xs) {
                        ForEach(0..<5, id: \.self) { index in
                            Capsule()
                                .fill(index == viewModel.currentStep ? ColorTokens.textPrimary : ColorTokens.textTertiary)
                                .frame(width: index == viewModel.currentStep ? 24 : 8, height: 8)
                                .animation(Animations.springBounce, value: viewModel.currentStep)
                        }
                    }

                    Spacer()

                    // Balance the back button width
                    Color.clear
                        .frame(width: 50, height: 1)
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.lg)
            }
        }
        .frame(minWidth: 920, minHeight: 620)
    }
}
