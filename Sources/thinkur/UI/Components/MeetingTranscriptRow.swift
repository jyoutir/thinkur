import SwiftUI

struct MeetingTranscriptRow: View {
    let speakerId: String
    let speakerName: String
    let timestamp: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Circle()
                .fill(MeetingSpeakerColor.color(for: speakerId))
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xs) {
                    Text(speakerName)
                        .font(Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(MeetingSpeakerColor.color(for: speakerId))

                    Text(timestamp)
                        .font(Typography.caption2)
                        .foregroundStyle(ColorTokens.textTertiary)
                }

                Text(text)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .textSelection(.enabled)
            }
        }
    }
}
