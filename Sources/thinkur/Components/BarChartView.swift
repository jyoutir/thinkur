import SwiftUI

struct BarChartView: View {
    let data: [(label: String, value: Double)]
    var barColor: Color = ColorTokens.accentBlue

    var body: some View {
        let maxValue = data.map(\.value).max() ?? 1.0
        let normalizedMax = maxValue > 0 ? maxValue : 1.0

        HStack(alignment: .bottom, spacing: Spacing.xs) {
            ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                VStack(spacing: Spacing.xxs) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor.opacity(0.8))
                        .frame(height: max(4, CGFloat(item.value / normalizedMax) * 100))

                    Text(item.label)
                        .font(Typography.caption2)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 130)
    }
}
