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
                            title: "Sound Effects",
                            subtitle: "Play sounds when starting and stopping recording",
                            isOn: $s.soundEffects
                        )

                        if settings.soundEffects {
                            Divider()

                            SoundStylePicker(selectedStyle: $s.soundStyle)
                        }

                        Divider()

                        ToggleRow(
                            icon: "speaker.wave.1",
                            title: "Dim Music While Recording",
                            subtitle: "Lower system volume while recording",
                            isOn: $s.dimMusicWhileRecording
                        )

                        Divider()

                        ToggleRow(
                            icon: "waveform",
                            title: "Floating Indicator",
                            subtitle: "Show waveform visualization while recording",
                            isOn: $s.floatingIndicator
                        )

                        Divider()

                        ToggleRow(
                            icon: "power",
                            title: "Launch at Login",
                            subtitle: "Start thinkur automatically when you log in",
                            isOn: $s.launchAtLogin
                        )

                        Divider()

                        ToggleRow(
                            icon: "arrow.triangle.2.circlepath",
                            title: "Automatic Updates",
                            subtitle: "Keep thinkur up to date automatically",
                            isOn: $s.automaticUpdates
                        )
                    }
                }

                // TODO: Remove this debug section before shipping
                GroupedSettingsSection(title: "Debug") {
                    Button {
                        coordinator.onboardingViewModel.currentStep = 0
                        coordinator.onboardingViewModel.isComplete = false
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundStyle(.primary)
                                .frame(width: 20)
                            Text("Replay Onboarding")
                                .foregroundStyle(ColorTokens.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                    }
                    .buttonStyle(.plain)
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

struct SoundStylePicker: View {
    @Binding var selectedStyle: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "music.note")
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .frame(width: 20)

            Text("Sound Style")
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimary)

            Spacer()

            HStack(spacing: Spacing.xs) {
                ForEach(SoundStyle.allCases) { style in
                    let isSelected = selectedStyle == style.rawValue
                    Button {
                        selectedStyle = style.rawValue
                        ToneGenerator.shared.preview(style: style)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: style.icon)
                                .font(.system(size: 10))
                            Text(style.displayName)
                                .font(Typography.caption)
                        }
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.xxs)
                        .background(
                            isSelected ? Color.accentColor.opacity(0.2) : Color.clear,
                            in: .capsule
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isSelected ? Color.accentColor : ColorTokens.border,
                                    lineWidth: 1
                                )
                        )
                        .foregroundStyle(isSelected ? Color.accentColor : ColorTokens.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 14)
    }
}
