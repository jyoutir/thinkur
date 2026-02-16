import SwiftUI

struct BillingView: View {
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("Manage your subscription and payment details.")
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textTertiary)

                GroupedSettingsSection(title: "Current Plan") {
                    VStack(spacing: 0) {
                        SettingsRowView(icon: "crown.fill", title: "Plan") {
                            Text("Lifetime")
                                .font(Typography.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, Spacing.xs)
                                .padding(.vertical, Spacing.xxs)
                                .background(ColorTokens.textPrimary, in: Capsule())
                        }

                        Divider()

                        SettingsRowView(icon: "calendar", title: "Activated") {
                            Text("February 2026")
                                .font(Typography.body)
                                .foregroundStyle(ColorTokens.textSecondary)
                        }

                        Divider()

                        SettingsRowView(icon: "creditcard", title: "Payment") {
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
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 6)
            .animation(Animations.glassMaterialize, value: appeared)
        }
        .navigationTitle("Billing")
        .onAppear { appeared = true }
    }
}
