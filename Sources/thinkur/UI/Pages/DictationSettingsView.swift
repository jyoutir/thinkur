import SwiftUI

struct DictationSettingsView: View {
    @Environment(SettingsManager.self) private var settings

    var body: some View {
        @Bindable var s = settings

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("Fine-tune how your speech is processed and formatted.")
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textTertiary)

                GroupedSettingsSection(title: "Text Processing") {
                    VStack(spacing: 0) {
                        ToggleRow(
                            icon: "text.badge.minus",
                            iconColor: ColorTokens.accentOrange,
                            title: "Remove Filler Words",
                            subtitle: "Removes um, uh, like, you know",
                            isOn: $s.removeFillerWords
                        )

                        Divider()

                        ToggleRow(
                            icon: "textformat.abc",
                            iconColor: ColorTokens.accentBlue,
                            title: "Auto Punctuation",
                            subtitle: "Automatically adds periods, commas, and question marks",
                            isOn: $s.autoPunctuation
                        )

                        Divider()

                        ToggleRow(
                            icon: "wand.and.stars",
                            iconColor: ColorTokens.accentPurple,
                            title: "Intent Correction",
                            subtitle: "Fixes self-corrections like 'I went to the sto... restaurant'",
                            isOn: $s.intentCorrection
                        )

                        Divider()

                        ToggleRow(
                            icon: "number",
                            iconColor: ColorTokens.accentGreen,
                            title: "Smart Formatting",
                            subtitle: "Formats numbers, dates, and common patterns",
                            isOn: $s.smartFormatting
                        )

                        Divider()

                        ToggleRow(
                            icon: "chevron.left.forwardslash.chevron.right",
                            iconColor: ColorTokens.textSecondary,
                            title: "Code Context",
                            subtitle: "Preserves code-specific formatting when dictating in editors",
                            isOn: $s.codeContext
                        )

                        Divider()

                        ToggleRow(
                            icon: "brain",
                            iconColor: ColorTokens.accentRed,
                            title: "Learn from Corrections",
                            subtitle: "Improves accuracy based on your editing patterns",
                            isOn: $s.learnFromCorrections
                        )
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .navigationTitle("Dictation")
    }
}
