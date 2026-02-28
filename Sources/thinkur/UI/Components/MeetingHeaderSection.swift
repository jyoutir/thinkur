import SwiftUI

struct MeetingHeaderSection: View {
    @Bindable var meeting: MeetingRecord
    @Environment(SettingsManager.self) private var settings

    @State private var showRenameSheet = false
    @State private var editingTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Text(meeting.title)
                    .font(Typography.title2)
                    .foregroundStyle(ColorTokens.textPrimary)

                Button {
                    editingTitle = meeting.title
                    showRenameSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Text(meeting.date, format: .dateTime.month().day().year().hour().minute())
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .sheet(isPresented: $showRenameSheet) {
            VStack(spacing: 16) {
                Text("Rename Meeting").font(Typography.headline)
                TextField("Meeting title", text: $editingTitle)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Cancel") { showRenameSheet = false }
                    Spacer()
                    Button("Save") {
                        meeting.title = editingTitle
                        showRenameSheet = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(width: 320)
        }
    }
}
