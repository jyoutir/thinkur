import SwiftUI

struct LanguageSettingsView: View {
    @Environment(SettingsManager.self) private var settings
    @Environment(AppCoordinator.self) private var coordinator
    @State private var appeared = false

    private let languages = ["English", "Spanish", "French", "German", "Italian", "Portuguese", "Chinese", "Japanese", "Korean"]
    private let modelSizes = ["tiny.en", "base.en", "small.en", "medium.en", "large-v3"]

    var body: some View {
        @Bindable var s = settings

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("Set your language and choose a transcription model.")
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textTertiary)

                GroupedSettingsSection(title: "Language") {
                    VStack(spacing: 0) {
                        SettingsRowView(icon: "globe", iconColor: .primary, title: "Primary Language") {
                            Picker("", selection: $s.selectedLanguage) {
                                ForEach(languages, id: \.self) { lang in
                                    Text(lang).tag(lang)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 140)
                        }

                        Divider()

                        ToggleRow(
                            icon: "globe.americas",
                            iconColor: .primary,
                            title: "Multilingual Mode",
                            subtitle: "Auto-detect and transcribe multiple languages",
                            isOn: $s.multilingualMode
                        )
                    }
                }

                GroupedSettingsSection(title: "Model") {
                    SettingsRowView(icon: "cpu", iconColor: .primary, title: "Model Size", subtitle: "Larger models are more accurate but slower") {
                        Picker("", selection: $s.modelSize) {
                            ForEach(modelSizes, id: \.self) { size in
                                Text(size).tag(size)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 140)
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
        .navigationTitle("Language")
        .onAppear { appeared = true }
        .onChange(of: settings.modelSize) {
            Task { await coordinator.retryModelLoad() }
        }
    }
}
