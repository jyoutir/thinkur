import SwiftUI

struct StyleAppRow: View {
    let entry: StyleAppEntry
    let onStyleChange: (String) -> Void

    private let styles = ["Standard", "Casual", "Formal", "Code"]

    var body: some View {
        HStack(spacing: Spacing.sm) {
            AppIconView(
                letter: String(entry.appName.prefix(1)),
                color: iconColor(for: entry.iconColor),
                size: 32
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.appName)
                    .font(Typography.headline)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text(entry.description)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            Spacer()

            Picker("", selection: Binding(
                get: { entry.style },
                set: { onStyleChange($0) }
            )) {
                ForEach(styles, id: \.self) { style in
                    Text(style).tag(style)
                }
            }
            .labelsHidden()
            .frame(width: 100)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    private func iconColor(for name: String) -> Color {
        switch name {
        case "purple": return ColorTokens.accentPurple
        case "blue": return ColorTokens.accentBlue
        case "yellow": return ColorTokens.accentYellow
        case "orange": return ColorTokens.accentOrange
        case "green": return ColorTokens.accentGreen
        case "red": return ColorTokens.accentRed
        default: return ColorTokens.accentBlue
        }
    }
}
