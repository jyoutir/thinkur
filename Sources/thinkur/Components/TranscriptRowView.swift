import SwiftUI

struct TranscriptRowView: View {
    let appName: String
    let timestamp: Date
    let preview: String
    let appColor: Color

    var body: some View {
        HStack(spacing: Spacing.sm) {
            AppIconView(letter: String(appName.prefix(1)), color: appColor, size: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(appName)
                        .font(Typography.headline)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Spacer()
                    Text(timestamp, format: .dateTime.hour().minute())
                        .font(Typography.caption2)
                        .foregroundStyle(ColorTokens.textTertiary)
                }

                Text(preview)
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, Spacing.xxs)
    }
}
