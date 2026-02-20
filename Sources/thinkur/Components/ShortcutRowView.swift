import SwiftUI

struct ShortcutRowView: View {
    let shortcut: Shortcut
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            KeyboardShortcutBadge(key: shortcut.trigger)

            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundStyle(ColorTokens.textTertiary)

            Text(shortcut.expansion)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimary)
                .lineLimit(1)

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(isHovering ? ColorTokens.danger : ColorTokens.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .onHover { hovering in
            withAnimation(Animations.hoverFade) {
                isHovering = hovering
            }
        }
    }
}
