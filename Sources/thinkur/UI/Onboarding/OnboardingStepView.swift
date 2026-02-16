import SwiftUI

struct OnboardingStepView: View {
    let step: OnboardingStepData
    let onAction: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Text(step.emoji)
                .font(Typography.onboardingEmoji)

            Text(step.title)
                .font(Typography.onboardingTitle)
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)

            Text(step.description)
                .font(Typography.onboardingBody)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            if !step.bullets.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(step.bullets, id: \.self) { bullet in
                        HStack(alignment: .top, spacing: Spacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.primary)
                                .font(.system(size: 14))
                            Text(bullet)
                                .font(Typography.body)
                                .foregroundStyle(ColorTokens.textSecondary)
                        }
                    }
                }
                .padding(.top, Spacing.sm)
            }

            Spacer()

            Button(action: onAction) {
                Text(step.ctaLabel)
                    .font(Typography.headline)
                    .frame(maxWidth: 280)
                    .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(.primary)

            Spacer()
                .frame(height: Spacing.xl)
        }
        .padding(.horizontal, Spacing.xl)
    }
}
