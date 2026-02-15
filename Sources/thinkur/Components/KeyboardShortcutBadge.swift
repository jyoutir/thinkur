import SwiftUI

struct KeyboardShortcutBadge: View {
    let key: String

    var body: some View {
        Text(key)
            .font(Typography.keyboardBadge)
            .foregroundStyle(ColorTokens.textPrimary)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .background(ColorTokens.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.button))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.button)
                    .stroke(ColorTokens.border, lineWidth: 0.5)
            )
    }
}
