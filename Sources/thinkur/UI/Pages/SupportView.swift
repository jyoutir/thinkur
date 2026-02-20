import SwiftUI

struct SupportView: View {
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("About thinkur.")
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textTertiary)

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
}
