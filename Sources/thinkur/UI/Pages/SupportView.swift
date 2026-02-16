import SwiftUI

struct SupportView: View {
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("Get help, report bugs, or contact the team.")
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textTertiary)

                GroupedSettingsSection(title: "Help") {
                    VStack(spacing: 0) {
                        supportLink(
                            icon: "book",
                            title: "Documentation",
                            subtitle: "Learn how to use thinkur"
                        )

                        Divider()

                        supportLink(
                            icon: "bubble.left.and.bubble.right",
                            title: "Community",
                            subtitle: "Join the thinkur community"
                        )

                        Divider()

                        supportLink(
                            icon: "envelope",
                            title: "Contact Support",
                            subtitle: "Get help from the team"
                        )

                        Divider()

                        supportLink(
                            icon: "ladybug",
                            title: "Report a Bug",
                            subtitle: "Help us improve thinkur"
                        )
                    }
                }

                GroupedSettingsSection(title: "About") {
                    SettingsRowView(icon: "info.circle", title: "Version") {
                        Text("1.0.0")
                            .font(Typography.body)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.lg)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 6)
            .animation(Animations.glassMaterialize, value: appeared)
        }
        .navigationTitle("Support")
        .onAppear { appeared = true }
    }

    @ViewBuilder
    private func supportLink(icon: String, title: String, subtitle: String) -> some View {
        SettingsRowView(icon: icon, title: title, subtitle: subtitle) {
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }
}
