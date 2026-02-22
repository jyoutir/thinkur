import SwiftUI

struct OnboardingFlow: View {
    @Environment(OnboardingViewModel.self) private var viewModel
    @Environment(SettingsManager.self) private var settings

    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            HStack(spacing: Spacing.xl) {
                sidebar
                    .frame(width: 240, alignment: .leading)

                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: Spacing.md)

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
                            ForEach(0..<stepItems.count, id: \.self) { index in
                                Capsule()
                                    .fill(index == viewModel.currentStep ? settings.accentUITint : ColorTokens.textTertiary)
                                    .frame(width: index == viewModel.currentStep ? 24 : 8, height: 8)
                                    .animation(Animations.springBounce, value: viewModel.currentStep)
                            }
                        }

                        Spacer()

                        Color.clear
                            .frame(width: 50, height: 1)
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.bottom, Spacing.lg)
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.lg)
        }
        .frame(minWidth: 1000, minHeight: 650)
    }

    @ViewBuilder
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("thinkur")
                    .font(Typography.title2)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text("Setup in five short steps")
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(Array(stepItems.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: Spacing.xs) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index == viewModel.currentStep ? settings.accentUITint : ColorTokens.textTertiary.opacity(0.35))
                            .frame(width: 3, height: 26)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Step \(index + 1)")
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textTertiary)
                            Text(step)
                                .font(Typography.headline)
                                .foregroundStyle(index == viewModel.currentStep ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: Spacing.xxs + 2) {
                Text("$29 lifetime")
                Text("$5 monthly")
                Text("On-device")
                Text("No account needed")
            }
            .font(Typography.caption)
            .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(Spacing.lg)
        .glassCard(cornerRadius: CornerRadius.window)
    }

    private var stepItems: [String] {
        [
            "Permissions",
            "Model + Value",
            "Quick Settings",
            "Try It",
            "Activate"
        ]
    }
}
