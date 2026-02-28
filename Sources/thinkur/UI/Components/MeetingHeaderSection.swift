import SwiftUI

struct MeetingHeaderSection: View {
    @Bindable var meeting: MeetingRecord
    @Environment(SettingsManager.self) private var settings

    @State private var isEditing = false
    @State private var originalTitle = ""
    @FocusState private var titleFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if isEditing {
                HStack(spacing: Spacing.sm) {
                    TextField("Meeting title", text: $meeting.title)
                        .font(Typography.title2)
                        .textFieldStyle(.roundedBorder)
                        .focused($titleFieldFocused)
                        .onSubmit { isEditing = false }

                    Button("Cancel") {
                        meeting.title = originalTitle
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
                        originalTitle = meeting.title
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
}
