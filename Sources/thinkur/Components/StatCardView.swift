import SwiftUI

struct StatCardView: View {
    let title: String
    let value: String
    let unit: String
    var change: String? = nil
    var tint: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                Text(value)
                    .font(Typography.statValue)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text(unit)
                    .font(Typography.statUnit)
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            if let change {
                Text(change)
                    .font(Typography.caption2)
                    .foregroundStyle(ColorTokens.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .modifier(StatCardGlassModifier(tint: tint))
    }
}

private struct StatCardGlassModifier: ViewModifier {
    let tint: Color?

    func body(content: Content) -> some View {
        if let tint {
            content.glassTinted(tint)
        } else {
            content.glassCard()
        }
    }
}
