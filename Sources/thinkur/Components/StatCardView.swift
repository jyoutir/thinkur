import SwiftUI

struct StatCardView: View {
    let title: String
    let value: String
    let unit: String
    var change: String? = nil

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
                    .foregroundStyle(ColorTokens.success)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .glassCard()
    }
}
