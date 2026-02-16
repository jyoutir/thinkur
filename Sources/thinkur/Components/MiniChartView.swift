import SwiftUI

struct MiniChartView: View {
    let values: [Double]
    var barColor: Color = .primary

    var body: some View {
        let maxValue = values.max() ?? 1.0
        let normalizedMax = maxValue > 0 ? maxValue : 1.0

        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(barColor.opacity(0.7))
                    .frame(width: 4, height: max(2, CGFloat(value / normalizedMax) * 24))
            }
        }
        .frame(height: 28)
    }
}
