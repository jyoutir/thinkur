import SwiftUI

struct MeetingHeaderSection: View {
    @Environment(MeetingViewModel.self) private var viewModel
    @Environment(SettingsManager.self) private var settings

    let meeting: MeetingRecord

    @State private var editingTitle: String
    @State private var isEditing = false
    @FocusState private var titleFieldFocused: Bool

    init(meeting: MeetingRecord) {
        self.meeting = meeting
        self._editingTitle = State(initialValue: meeting.title)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if isEditing {
                HStack(spacing: Spacing.sm) {
                    TextField("Meeting title", text: $editingTitle)
                        .font(Typography.title2)
                        .textFieldStyle(.roundedBorder)
                        .focused($titleFieldFocused)
                        .onSubmit { saveTitle() }

                    Button("Save") { saveTitle() }
                        .font(Typography.caption)
                        .buttonStyle(.plain)
                        .foregroundStyle(settings.accentUITint)

                    Button("Cancel") {
                        editingTitle = meeting.title
                        isEditing = false
                    }
                    .font(Typography.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(ColorTokens.textTertiary)
                }
            } else {
                HStack(spacing: Spacing.xs) {
                    Text(meeting.title)
                        .font(Typography.title2)
                        .foregroundStyle(ColorTokens.textPrimary)

                    Button {
                        editingTitle = meeting.title
                        isEditing = true
                        DispatchQueue.main.async { titleFieldFocused = true }
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundStyle(ColorTokens.textTertiary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(meeting.date, format: .dateTime.month().day().year().hour().minute())
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }

    private func saveTitle() {
        viewModel.updateTitle(meeting: meeting, title: editingTitle)
        isEditing = false
    }
}
