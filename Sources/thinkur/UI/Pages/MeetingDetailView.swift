import SwiftUI

struct MeetingDetailView: View {
    @Environment(MeetingViewModel.self) private var viewModel
    @Environment(SettingsManager.self) private var settings

    let meeting: MeetingRecord

    @State private var editingTitle: String = ""
    @State private var isEditingTitle = false
    @State private var editingSpeakerId: String?
    @State private var editingSpeakerName: String = ""
    @State private var appeared = false
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Back button
                Button {
                    viewModel.selectedMeeting = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Meetings")
                            .font(Typography.body)
                    }
                    .foregroundStyle(settings.accentUITint)
                }
                .buttonStyle(.plain)

                // Header
                headerSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(Animations.glassStagger(index: 0), value: appeared)

                // Stats
                statsSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(Animations.glassStagger(index: 1), value: appeared)

                Divider()

                // Transcript
                transcriptSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(Animations.glassStagger(index: 2), value: appeared)
            }
            .padding(Spacing.lg)
        }
        .navigationTitle("Meeting")
        .onAppear {
            editingTitle = meeting.title
            appeared = true
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if isEditingTitle {
                HStack(spacing: Spacing.sm) {
                    TextField("Meeting title", text: $editingTitle)
                        .font(Typography.title2)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { saveTitle() }

                    Button("Save") { saveTitle() }
                        .font(Typography.caption)
                        .buttonStyle(.plain)
                        .foregroundStyle(settings.accentUITint)

                    Button("Cancel") {
                        editingTitle = meeting.title
                        isEditingTitle = false
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
                        isEditingTitle = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(meeting.date, format: .dateTime.month().day().year().hour().minute())
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }

    // MARK: - Stats

    @ViewBuilder
    private var statsSection: some View {
        HStack(spacing: Spacing.md) {
            statBadge(icon: "clock", value: formatDuration(meeting.duration))
            statBadge(icon: "person.2", value: "\(meeting.speakerCount) speakers")
            statBadge(icon: "text.alignleft", value: "\(meeting.segments.count) segments")

            Spacer()

            Button {
                guard !copied else { return }
                copyTranscript()
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    copied = false
                }
            } label: {
                ZStack {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                        Text("Copy Transcript")
                            .font(Typography.caption)
                    }
                    .foregroundStyle(settings.accentUITint)
                    .opacity(copied ? 0 : 1)

                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(settings.accentUITint)
                        Text("Copied to clipboard")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textPrimary)
                    }
                    .opacity(copied ? 1 : 0)
                    .scaleEffect(copied ? 1 : 0.8)
                }
                .animation(.spring(duration: 0.4, bounce: 0.2), value: copied)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func statBadge(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(value)
                .font(Typography.caption)
        }
        .foregroundStyle(ColorTokens.textPrimary)
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, 4)
        .glassClear(cornerRadius: CornerRadius.button)
    }

    // MARK: - Transcript

    @ViewBuilder
    private var transcriptSection: some View {
        if meeting.sortedSegments.isEmpty {
            GlassEmptyState(
                icon: "text.bubble",
                title: "No transcript",
                subtitle: "This meeting has no transcript segments"
            )
        } else {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(meeting.sortedSegments, id: \.id) { segment in
                    if editingSpeakerId == segment.speakerId {
                        // Inline speaker name editor
                        HStack(spacing: Spacing.sm) {
                            Circle()
                                .fill(MeetingSpeakerColor.color(for: segment.speakerId))
                                .frame(width: 8, height: 8)

                            TextField("Speaker name", text: $editingSpeakerName)
                                .font(Typography.caption)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 140)
                                .onSubmit {
                                    viewModel.updateSpeakerName(
                                        meeting: meeting,
                                        speakerId: segment.speakerId,
                                        name: editingSpeakerName
                                    )
                                    editingSpeakerId = nil
                                }

                            Button("Save") {
                                viewModel.updateSpeakerName(
                                    meeting: meeting,
                                    speakerId: segment.speakerId,
                                    name: editingSpeakerName
                                )
                                editingSpeakerId = nil
                            }
                            .font(Typography.caption)
                            .buttonStyle(.plain)
                            .foregroundStyle(settings.accentUITint)

                            Button("Cancel") {
                                editingSpeakerId = nil
                            }
                            .font(Typography.caption)
                            .buttonStyle(.plain)
                            .foregroundStyle(ColorTokens.textTertiary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        MeetingTranscriptRow(
                            speakerId: segment.speakerId,
                            speakerName: meeting.displayName(for: segment.speakerId),
                            timestamp: segment.formattedStartTime,
                            text: segment.text
                        )
                        .onTapGesture {
                            editingSpeakerId = segment.speakerId
                            editingSpeakerName = meeting.displayName(for: segment.speakerId)
                        }
                    }
                }
            }
            .padding(Spacing.md)
            .glassCard()
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    private func saveTitle() {
        viewModel.updateTitle(meeting: meeting, title: editingTitle)
        isEditingTitle = false
    }

    private func copyTranscript() {
        let lines = meeting.sortedSegments.map { segment in
            "[\(segment.formattedStartTime)] \(meeting.displayName(for: segment.speakerId)): \(segment.text)"
        }
        let text = lines.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
