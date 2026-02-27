import SwiftUI

struct ActiveMeetingView: View {
    @Environment(MeetingViewModel.self) private var viewModel
    @Environment(SettingsManager.self) private var settings

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Header: elapsed time + recording indicator
            HStack(spacing: Spacing.sm) {
                Circle()
                    .fill(.red)
                    .frame(width: 10, height: 10)
                    .opacity(pulseOpacity)

                Text(formatElapsedTime(viewModel.coordinator.elapsedTime))
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(ColorTokens.textPrimary)

                Spacer()

                if viewModel.coordinator.speakerCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2")
                            .font(.system(size: 12))
                        Text("\(viewModel.coordinator.speakerCount)")
                            .font(Typography.caption)
                    }
                    .foregroundStyle(ColorTokens.textSecondary)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 4)
                    .glassClear(cornerRadius: CornerRadius.button)
                }

                Button {
                    Task { await viewModel.stopMeeting() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10))
                        Text("Stop")
                            .font(Typography.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 6)
                    .background(.red, in: RoundedRectangle(cornerRadius: CornerRadius.button))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .glassCard()

            // Audio level bar
            AudioLevelBar(level: viewModel.coordinator.currentAudioLevel, accentColor: settings.accentUITint)
                .frame(height: 4)
                .padding(.horizontal, Spacing.md)

            // Loading state
            if viewModel.coordinator.isDiarizerLoading {
                VStack(spacing: Spacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text(viewModel.coordinator.diarizerLoadingMessage)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xl)
            }

            // Live transcript
            if !viewModel.coordinator.liveSegments.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: Spacing.sm) {
                            ForEach(Array(viewModel.coordinator.liveSegments.enumerated()), id: \.offset) { index, segment in
                                MeetingTranscriptRow(
                                    speakerId: segment.speakerId,
                                    speakerName: "Speaker \(segment.speakerId)",
                                    timestamp: MeetingSegment.formatTime(segment.startTime),
                                    text: segment.text
                                )
                                .id(index)
                            }
                        }
                        .padding(Spacing.md)
                    }
                    .glassCard()
                    .onChange(of: viewModel.coordinator.liveSegments.count) { _, _ in
                        let lastIndex = viewModel.coordinator.liveSegments.count - 1
                        if lastIndex >= 0 {
                            withAnimation {
                                proxy.scrollTo(lastIndex, anchor: .bottom)
                            }
                        }
                    }
                }
            } else if !viewModel.coordinator.isDiarizerLoading {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "waveform")
                        .font(.system(size: 32))
                        .foregroundStyle(settings.accentUITint.opacity(0.3))
                    Text("Listening...")
                        .font(Typography.headline)
                        .foregroundStyle(ColorTokens.textSecondary)
                    Text("Transcript will appear as people speak")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .glassClear()
            }
        }
    }

    // MARK: - Helpers

    @State private var pulsePhase = false

    private var pulseOpacity: Double {
        // Simple alternating opacity for recording dot
        1.0
    }

    private func formatElapsedTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - Audio Level Bar

private struct AudioLevelBar: View {
    let level: Float
    let accentColor: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(ColorTokens.border)

                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: max(0, geo.size.width * CGFloat(level)))
                    .animation(.easeOut(duration: 0.08), value: level)
            }
        }
    }
}
