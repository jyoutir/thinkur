import SwiftUI

struct BarChartView: View {
    let data: [(label: String, value: Double)]
    var barColor: Color = ColorTokens.accentBlue

    var body: some View {
        let maxValue = data.map(\.value).max() ?? 1.0
        let normalizedMax = maxValue > 0 ? maxValue : 1.0
        // Show every label for <=14 items, every other for <=21, every 3rd for more
        let labelStep = data.count <= 14 ? 1 : data.count <= 21 ? 2 : 3

        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(item.value > 0 ? barColor.opacity(0.8) : barColor.opacity(0.15))
                        .frame(height: max(4, CGFloat(item.value / normalizedMax) * 100))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 110)

            HStack(spacing: 2) {
                ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                    Text(index % labelStep == 0 ? item.label : "")
                        .font(Typography.caption2)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, Spacing.xxs)
        }
    }
}
