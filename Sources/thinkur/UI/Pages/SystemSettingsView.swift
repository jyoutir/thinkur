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

                GroupedSettingsSection(title: "Aesthetics") {
                    AccentColorPicker(selectedColor: $s.accentColorName)
                }

                // TODO: Remove this debug section before shipping
                GroupedSettingsSection(title: "Debug") {
                    Button {
                        coordinator.onboardingViewModel.currentStep = 0
                        coordinator.onboardingViewModel.isComplete = false
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundStyle(settings.accentUITint)
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

struct AccentColorPicker: View {
    @Binding var selectedColor: String
    @Environment(SettingsManager.self) private var settings

    private var currentColor: Color {
        (AccentColor(rawValue: selectedColor) ?? .defaultGreen).color
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "paintpalette")
                .font(.system(size: 14))
                .foregroundStyle(settings.accentUITint)
                .frame(width: 20)

            Text("Accent Color")
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimary)
                .fixedSize()

            Spacer()

            HStack(spacing: Spacing.xs) {
                ForEach(AccentColor.allCases) { accent in
                    let isSelected = selectedColor == accent.rawValue
                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            selectedColor = accent.rawValue
                        }
                    } label: {
                        Circle()
                            .fill(accent.color)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .fill(.white)
                                    .frame(width: 7, height: 7)
                                    .opacity(isSelected ? 1 : 0)
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        isSelected ? accent.color : Color.clear,
                                        lineWidth: 2
                                    )
                                    .frame(width: 22, height: 22)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(accent.displayName)
                }
            }

            IndicatorPreview(color: currentColor)
                .padding(.leading, Spacing.xs)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 14)
    }
}

/// Animated mini floating indicator preview that shows what the color controls
private struct IndicatorPreview: View {
    let color: Color
    @State private var phase: CGFloat = 0

    private let barCount = 14
    private let pixelSize: CGFloat = 2
    private let spacing: CGFloat = 1

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<barCount, id: \.self) { i in
                let normalized = Double(i) / Double(barCount - 1)
                let wave = (sin(phase + normalized * .pi * 2.5) + 1) / 2
                let height = pixelSize * (2 + round(wave * 3))

                RoundedRectangle(cornerRadius: 0.5)
                    .fill(color)
                    .frame(width: pixelSize, height: height)
            }
        }
        .frame(height: pixelSize * 5)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(.primary.opacity(0.1))
        )
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

struct SoundStylePicker: View {
    @Binding var selectedStyle: String
    @Environment(SettingsManager.self) private var settings

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "music.note")
                .font(.system(size: 14))
                .foregroundStyle(settings.accentUITint)
                .frame(width: 20)

            Text("Sound Style")
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimary)
                .fixedSize()

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
                                .lineLimit(1)
                                .fixedSize()
                        }
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.xxs)
                        .background(
                            isSelected ? settings.accentUITint.opacity(0.2) : Color.clear,
                            in: .capsule
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isSelected ? settings.accentUITint : ColorTokens.border,
                                    lineWidth: 1
                                )
                        )
                        .foregroundStyle(isSelected ? settings.accentUITint : ColorTokens.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 14)
    }
}
