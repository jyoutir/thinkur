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
                    .opacity(pulsePhase ? 0.3 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulsePhase)
                    .onAppear { pulsePhase = true }

                Text(formatElapsedTime(viewModel.coordinator.elapsedTime))
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(ColorTokens.textPrimary)

                Spacer()

                if viewModel.coordinator.isSystemAudioActive {
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 12))
                        Text("System")
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
                .frame(height: 6)

            // Recording message
            VStack(spacing: Spacing.sm) {
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .opacity(pulsePhase ? 0.3 : 1.0)

                    Text("Recording")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                }

                Text("Transcript will be ready when the meeting ends")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)

            Spacer()
        }
        .padding(Spacing.lg)
    }

    // MARK: - Helpers

    @State private var pulsePhase = false

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
                RoundedRectangle(cornerRadius: 3)
                    .fill(ColorTokens.border)

                RoundedRectangle(cornerRadius: 3)
                    .fill(accentColor)
                    .frame(width: max(0, geo.size.width * CGFloat(level)))
                    .animation(.easeOut(duration: 0.08), value: level)
            }
        }
    }
}
