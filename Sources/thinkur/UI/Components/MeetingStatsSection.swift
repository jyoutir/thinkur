import SwiftUI

struct MeetingStatsSection: View {
    @Environment(MeetingViewModel.self) private var viewModel
    @Environment(SettingsManager.self) private var settings

    let meeting: MeetingRecord

    @State private var speakersExpanded = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(spacing: Spacing.md) {
                statBadge(icon: "clock", value: formatDuration(meeting.duration), label: "duration")

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
                    .fixedSize()
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .glassCard(cornerRadius: CornerRadius.button)
                }
                .buttonStyle(.plain)

                statBadge(
                    icon: "text.alignleft",
                    value: "\(meeting.segments.count)",
                    label: meeting.segments.count == 1 ? "exchange" : "exchanges"
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

            if speakersExpanded {
                speakersPanel
            }
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
        .fixedSize()
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .glassCard(cornerRadius: CornerRadius.button)
    }

    @ViewBuilder
    private var speakersPanel: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(uniqueSpeakers, id: \.speakerId) { speaker in
                SpeakerNameRow(
                    speakerId: speaker.speakerId,
                    initialName: meeting.displayName(for: speaker.speakerId),
                    segmentCount: speaker.segmentCount
                ) { name in
                    viewModel.updateSpeakerName(meeting: meeting, speakerId: speaker.speakerId, name: name)
                }
            }
        }
        .padding(Spacing.md)
        .interactiveCard()
    }

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

    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
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
