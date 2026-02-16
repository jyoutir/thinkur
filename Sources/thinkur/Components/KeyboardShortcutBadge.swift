import SwiftUI

struct KeyboardShortcutBadge: View {
    let key: String

    var body: some View {
        Text(key)
            .font(Typography.keyboardBadge)
            .foregroundStyle(ColorTokens.textPrimary)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .glassEffect(.clear, in: .capsule)
    }
}
