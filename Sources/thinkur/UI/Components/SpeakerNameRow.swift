import SwiftUI

struct SpeakerNameRow: View {
    let speakerId: String
    let initialName: String
    let segmentCount: Int
    let onCommit: (String) -> Void

    @State private var text: String

    init(speakerId: String, initialName: String, segmentCount: Int, onCommit: @escaping (String) -> Void) {
        self.speakerId = speakerId
        self.initialName = initialName
        self.segmentCount = segmentCount
        self.onCommit = onCommit
        self._text = State(initialValue: initialName)
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(MeetingSpeakerColor.color(for: speakerId))
                .frame(width: 8, height: 8)

            TextField("Speaker name", text: $text)
                .font(Typography.body)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
                .onSubmit {
                    guard !text.isEmpty else { return }
                    onCommit(text)
                }

            Text("\(segmentCount) \(segmentCount == 1 ? "exchange" : "exchanges")")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)

            Spacer()
        }
    }
}
