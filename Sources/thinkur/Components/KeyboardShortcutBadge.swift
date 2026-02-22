import SwiftUI

struct KeyboardShortcutBadge: View {
    @Environment(SettingsManager.self) private var settings
    let key: String

    var body: some View {
        Text(key)
            .font(Typography.keyboardBadge)
            .foregroundStyle(settings.accentUITint)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .glassEffect(.clear, in: .capsule)
    }
}
