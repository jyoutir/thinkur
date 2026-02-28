import SwiftUI

struct MeetingDetailView: View {
    @Environment(MeetingViewModel.self) private var viewModel
    @Environment(SettingsManager.self) private var settings

    let meeting: MeetingRecord

    @State private var editingTitle: String = ""
    @State private var isEditingTitle = false
    @State private var speakersExpanded = false
    @State private var editedSpeakerNames: [String: String] = [:]
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

                // Expandable speakers panel
                if speakersExpanded {
                    speakersPanel
                }

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

    // MARK: - Stats

    @ViewBuilder
    private var statsSection: some View {
        HStack(spacing: Spacing.md) {
            statBadge(icon: "clock", value: formatDuration(meeting.duration), label: "duration")

            // Speakers badge as expandable button
            Button {
                withAnimation(Animations.glassMorph) {
                    speakersExpanded.toggle()
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "person.2")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text("\(meeting.speakerCount)")
                        .font(Typography.headline)
                        .foregroundStyle(settings.accentUITint)
                    Text(meeting.speakerCount == 1 ? "speaker" : "speakers")
                        .font(Typography.callout)
                        .foregroundStyle(ColorTokens.textTertiary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .rotationEffect(speakersExpanded ? .degrees(90) : .zero)
                        .animation(Animations.glassMorph, value: speakersExpanded)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .glassCard(cornerRadius: CornerRadius.button)
            }
            .buttonStyle(.plain)

            statBadge(
                icon: "text.alignleft",
                value: "\(meeting.segments.count)",
                label: meeting.segments.count == 1 ? "segment" : "segments"
            )

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
    private func statBadge(icon: String, value: String, label: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(ColorTokens.textTertiary)
            Text(value)
                .font(Typography.headline)
                .foregroundStyle(settings.accentUITint)
            Text(label)
                .font(Typography.callout)
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .glassCard(cornerRadius: CornerRadius.button)
    }

    // MARK: - Speakers Panel

    @ViewBuilder
    private var speakersPanel: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(uniqueSpeakers, id: \.speakerId) { speaker in
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(MeetingSpeakerColor.color(for: speaker.speakerId))
                        .frame(width: 8, height: 8)

                    TextField("Speaker name", text: speakerNameBinding(for: speaker.speakerId))
                        .font(Typography.body)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                        .onSubmit {
                            saveSpeakerName(speakerId: speaker.speakerId)
                        }

                    Text("\(speaker.segmentCount) \(speaker.segmentCount == 1 ? "segment" : "segments")")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)

                    Spacer()
                }
            }
        }
        .padding(Spacing.md)
        .glassCard()
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

    // MARK: - Helpers

    private var uniqueSpeakers: [(speakerId: String, segmentCount: Int)] {
        var counts: [String: Int] = [:]
        for segment in meeting.sortedSegments {
            counts[segment.speakerId, default: 0] += 1
        }
        return counts.sorted { lhs, rhs in
            if lhs.key == "local" { return true }
            if rhs.key == "local" { return false }
            return lhs.key < rhs.key
        }.map { (speakerId: $0.key, segmentCount: $0.value) }
    }

    private func speakerNameBinding(for speakerId: String) -> Binding<String> {
        Binding(
            get: { editedSpeakerNames[speakerId] ?? meeting.displayName(for: speakerId) },
            set: { editedSpeakerNames[speakerId] = $0 }
        )
    }

    private func saveSpeakerName(speakerId: String) {
        guard let name = editedSpeakerNames[speakerId], !name.isEmpty else { return }
        viewModel.updateSpeakerName(meeting: meeting, speakerId: speakerId, name: name)
    }

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
