import SwiftUI

struct SupportView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                GroupedSettingsSection(title: "Help") {
                    VStack(spacing: 0) {
                        supportLink(
                            icon: "book",
                            iconColor: ColorTokens.accentBlue,
                            title: "Documentation",
                            subtitle: "Learn how to use thinkur"
                        )

                        Divider()

                        supportLink(
                            icon: "bubble.left.and.bubble.right",
                            iconColor: ColorTokens.accentGreen,
                            title: "Community",
                            subtitle: "Join the thinkur community"
                        )

                        Divider()

                        supportLink(
                            icon: "envelope",
                            iconColor: ColorTokens.accentOrange,
                            title: "Contact Support",
                            subtitle: "Get help from the team"
                        )

                        Divider()

                        supportLink(
                            icon: "ladybug",
                            iconColor: ColorTokens.accentRed,
                            title: "Report a Bug",
                            subtitle: "Help us improve thinkur"
                        )
                    }
                }

                GroupedSettingsSection(title: "About") {
                    SettingsRowView(icon: "info.circle", iconColor: ColorTokens.textSecondary, title: "Version") {
                        Text("1.0.0")
                            .font(Typography.body)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
            }
            .padding(Spacing.lg)
        }
        .navigationTitle("Support")
    }

    @ViewBuilder
    private func supportLink(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        SettingsRowView(icon: icon, iconColor: iconColor, title: title, subtitle: subtitle) {
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }
}
