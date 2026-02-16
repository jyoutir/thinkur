import SwiftUI

struct SystemSettingsView: View {
    @Environment(SettingsManager.self) private var settings
    @Environment(AppCoordinator.self) private var coordinator
    @State private var showClearConfirmation = false
    @State private var appeared = false

    var body: some View {
        @Bindable var s = settings

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("Control app behavior, sounds, and startup preferences.")
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textTertiary)

                GroupedSettingsSection(title: "General") {
                    VStack(spacing: 0) {
                        ToggleRow(
                            icon: "speaker.wave.2",
                            iconColor: .primary,
                            title: "Sound Effects",
                            subtitle: "Play sounds when starting and stopping recording",
                            isOn: $s.soundEffects
                        )

                        Divider()

                        ToggleRow(
                            icon: "pause.circle",
                            iconColor: .primary,
                            title: "Pause Music While Recording",
                            subtitle: "Automatically pause playback during dictation",
                            isOn: $s.pauseMusicWhileRecording
                        )

                        Divider()

                        ToggleRow(
                            icon: "waveform",
                            iconColor: .primary,
                            title: "Floating Indicator",
                            subtitle: "Show waveform visualization while recording",
                            isOn: $s.floatingIndicator
                        )

                        Divider()

                        ToggleRow(
                            icon: "power",
                            iconColor: .primary,
                            title: "Launch at Login",
                            subtitle: "Start thinkur automatically when you log in",
                            isOn: $s.launchAtLogin
                        )

                        Divider()

                        ToggleRow(
                            icon: "arrow.triangle.2.circlepath",
                            iconColor: .primary,
                            title: "Automatic Updates",
                            subtitle: "Keep thinkur up to date automatically",
                            isOn: $s.automaticUpdates
                        )
                    }
                }

                GroupedSettingsSection(title: "Data") {
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundStyle(ColorTokens.danger)
                                .frame(width: 20)
                            Text("Clear All History")
                                .foregroundStyle(ColorTokens.danger)
                            Spacer()
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                    }
                    .buttonStyle(.plain)
                    .alert("Clear All History?", isPresented: $showClearConfirmation) {
                        Button("Cancel", role: .cancel) {}
                        Button("Clear", role: .destructive) {
                            Task { await coordinator.clearAllHistory() }
                        }
                    } message: {
                        Text("This will permanently delete all transcription history, analytics data, and usage statistics. This cannot be undone.")
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.lg)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 6)
            .animation(Animations.glassMaterialize, value: appeared)
        }
        .navigationTitle("System")
        .onAppear { appeared = true }
    }
}
