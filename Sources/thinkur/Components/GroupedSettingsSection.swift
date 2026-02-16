import SwiftUI

struct GroupedSettingsSection<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .textCase(.uppercase)
                    .padding(.bottom, Spacing.sm)
            }

            VStack(spacing: 0) {
                content
            }
            .glassCard()
        }
    }
}
