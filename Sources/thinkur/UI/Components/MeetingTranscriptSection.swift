import SwiftUI

struct MeetingTranscriptSection: View {
    let meeting: MeetingRecord

    var body: some View {
        if meeting.sortedSegments.isEmpty {
            GlassEmptyState(
                icon: "text.bubble",
                title: "No transcript",
                subtitle: "This meeting has no transcript segments"
            )
        } else {
            let segments = meeting.sortedSegments
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                    MeetingTranscriptRow(
                        speakerId: segment.speakerId,
                        speakerName: meeting.displayName(for: segment.speakerId),
                        timestamp: segment.formattedStartTime,
                        text: segment.text
                    )
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if index < segments.count - 1 {
                        Divider()
                            .padding(.leading, Spacing.md + 8 + Spacing.sm)
                    }
                }
            }
            .glassCard()
        }
    }
}
