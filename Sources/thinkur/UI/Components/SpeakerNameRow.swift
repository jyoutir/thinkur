import SwiftUI

struct SpeakerNameRow: View {
    let speakerId: String
    @Binding var name: String
    let segmentCount: Int
    var onCommit: () -> Void = {}

    @State private var showRename = false
    @State private var editingName = ""

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(MeetingSpeakerColor.color(for: speakerId))
                .frame(width: 8, height: 8)

            Button {
                editingName = name
                showRename = true
            } label: {
                Text(name)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)
                Image(systemName: "pencil")
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showRename) {
                VStack(spacing: 12) {
                    TextField("Speaker name", text: $editingName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                        .onSubmit {
                            name = editingName
                            onCommit()
                            showRename = false
                        }
                    HStack {
                        Button("Cancel") { showRename = false }
                            .buttonStyle(.plain)
                            .foregroundStyle(ColorTokens.textTertiary)
                        Spacer()
                        Button("Save") {
                            name = editingName
                            onCommit()
                            showRename = false
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(12)
            }

            Text("\(segmentCount) \(segmentCount == 1 ? "exchange" : "exchanges")")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)

            Spacer()
        }
    }
}
