import SwiftUI

struct DictationSettingsView: View {
    @Environment(SettingsManager.self) private var settings
    @State private var appeared = false

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
                            icon: "wand.and.stars.inverse",
                            title: "Text Processing",
                            subtitle: "Apply corrections and formatting to transcriptions",
                            isOn: $s.postProcessingEnabled
                        )

                        Divider()

                        Group {
                            ToggleRow(
                                icon: "text.badge.minus",
                                title: "Remove Filler Words",
                                subtitle: "Removes um, uh, like, you know",
                                isOn: $s.removeFillerWords
                            )

                            Divider()

                            ToggleRow(
                                icon: "textformat.abc",
                                title: "Auto Punctuation",
                                subtitle: "Automatically adds periods, commas, and question marks",
                                isOn: $s.autoPunctuation
                            )

                            Divider()

                            ToggleRow(
                                icon: "wand.and.stars",
                                title: "Intent Correction",
                                subtitle: "Fixes self-corrections like 'I went to the sto... restaurant'",
                                isOn: $s.intentCorrection
                            )

                            Divider()

                            ToggleRow(
                                icon: "number",
                                title: "Smart Formatting",
                                subtitle: "Formats numbers, dates, and common patterns",
                                isOn: $s.smartFormatting
                            )
                        }
                        .disabled(!settings.postProcessingEnabled)
                        .opacity(settings.postProcessingEnabled ? 1 : 0.5)
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
        .navigationTitle("Dictation")
        .onAppear { appeared = true }
    }
}
