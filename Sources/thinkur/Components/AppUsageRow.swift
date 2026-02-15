import SwiftUI

struct AppUsageRow: View {
    let appName: String
    let percentage: Double
    let wordCount: Int
    var color: Color = ColorTokens.accentBlue

    var body: some View {
        HStack(spacing: Spacing.sm) {
            AppIconView(letter: String(appName.prefix(1)), color: color, size: 24)

            Text(appName)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimary)
                .frame(width: 80, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ColorTokens.border)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: max(4, geo.size.width * percentage / 100), height: 6)
                }
            }
            .frame(height: 6)

            Text("\(Int(percentage))%")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)
                .monospacedDigit()
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.vertical, Spacing.xxs)
    }
}
