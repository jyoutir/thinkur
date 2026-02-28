import SwiftUI

struct SpeakerNameRow: View {
    let speakerId: String
    @Binding var name: String
    let segmentCount: Int
    var onCommit: () -> Void = {}

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(MeetingSpeakerColor.color(for: speakerId))
                .frame(width: 8, height: 8)

            TextField("Speaker name", text: $name)
                .font(Typography.body)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
                .onSubmit { onCommit() }

            Text("\(segmentCount) \(segmentCount == 1 ? "exchange" : "exchanges")")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)

            Spacer()
        }
    }
}
