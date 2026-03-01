import SwiftUI

struct MeetingsView: View {
    @Environment(MeetingViewModel.self) private var viewModel
    @Environment(PermissionManager.self) private var permissionManager
    @Environment(SettingsManager.self) private var settings
    @State private var appeared = false

    var body: some View {
        Group {
            if viewModel.coordinator.isRecording {
                ActiveMeetingView()
            } else if viewModel.coordinator.processingState == .processing {
                MeetingProcessingView()
            } else if !permissionManager.screenRecordingGranted || !settings.hasDeepgramKey {
                MeetingSetupView()
            } else if let meeting = viewModel.selectedMeeting {
                MeetingDetailView(meeting: meeting)
            } else {
                meetingsList
            }
        }
        .navigationTitle("Meetings")
        .task {
            permissionManager.checkScreenRecording()
            viewModel.loadMeetings()
        }
        .onAppear { appeared = true }
    }

    // MARK: - Meetings List

    @ViewBuilder
    private var meetingsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Record and transcribe conversations.")
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textTertiary)

                // Start meeting button
                Button {
                    Task { await viewModel.startMeeting() }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "record.circle")
                            .font(.system(size: 14))
                        Text("Start Meeting")
                            .font(Typography.body)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(settings.accentUITint, in: RoundedRectangle(cornerRadius: CornerRadius.button))
                }
                .buttonStyle(.plain)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(Animations.glassStagger(index: 0), value: appeared)

                // Error
                if let error = viewModel.coordinator.error {
                    Text(error)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.danger)
                        .padding(Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .materialClear()
                }

                // Past meetings
                if viewModel.meetings.isEmpty {
                    GlassEmptyState(
                        icon: "person.2.wave.2",
                        title: "No meetings yet",
                        subtitle: "Start a meeting to record and transcribe."
                    )
                    .opacity(appeared ? 1 : 0)
                    .animation(Animations.glassMaterialize, value: appeared)
                } else {
                    VStack(spacing: Spacing.sm) {
                        Text("Past Meetings")
                            .font(Typography.headline)
                            .foregroundStyle(ColorTokens.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(Array(viewModel.meetings.enumerated()), id: \.element.id) { index, meeting in
                            meetingCard(meeting: meeting, index: index)
                        }
                    }
                }
            }
            .padding(Spacing.lg)
        }
    }

    @ViewBuilder
    private func meetingCard(meeting: MeetingRecord, index: Int) -> some View {
        Button {
            viewModel.selectedMeeting = meeting
        } label: {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(meeting.title)
                        .font(Typography.body)
                        .fontWeight(.medium)
                        .foregroundStyle(ColorTokens.textPrimary)

                    HStack(spacing: Spacing.xs) {
                        Text(meeting.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)

                        Text("\u{00B7}")
                            .foregroundStyle(ColorTokens.textTertiary)

                        Text(formatDuration(meeting.duration))
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)

                        Text("\u{00B7}")
                            .foregroundStyle(ColorTokens.textTertiary)

                        HStack(spacing: 2) {
                            Image(systemName: "person.2")
                                .font(.system(size: 10))
                            Text("\(meeting.speakerCount)")
                                .font(Typography.caption)
                        }
                        .foregroundStyle(ColorTokens.textTertiary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(Spacing.md)
            .interactiveCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                viewModel.deleteMeeting(meeting)
            } label: {
                Label("Delete Meeting", systemImage: "trash")
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .animation(Animations.glassStagger(index: index + 1), value: appeared)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
