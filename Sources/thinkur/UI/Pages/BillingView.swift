import SwiftUI

struct BillingView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("Manage your subscription and payment details.")
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textTertiary)

                GroupedSettingsSection(title: "Current Plan") {
                    VStack(spacing: 0) {
                        SettingsRowView(icon: "crown.fill", iconColor: ColorTokens.accentYellow, title: "Plan") {
                            Text("Lifetime")
                                .font(Typography.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, Spacing.xs)
                                .padding(.vertical, Spacing.xxs)
                                .background(ColorTokens.success, in: Capsule())
                        }

                        Divider()

                        SettingsRowView(icon: "calendar", iconColor: ColorTokens.accentBlue, title: "Activated") {
                            Text("February 2026")
                                .font(Typography.body)
                                .foregroundStyle(ColorTokens.textSecondary)
                        }

                        Divider()

                        SettingsRowView(icon: "creditcard", iconColor: ColorTokens.accentGreen, title: "Payment") {
                            Text("One-time purchase")
                                .font(Typography.body)
                                .foregroundStyle(ColorTokens.textSecondary)
                        }
                    }
                }

                Button("Manage Subscription") {}
                    .controlSize(.regular)
                    .disabled(true)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .navigationTitle("Billing")
    }
}
