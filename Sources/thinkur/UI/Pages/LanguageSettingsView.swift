import SwiftUI

struct LanguageSettingsView: View {
    @Environment(SettingsManager.self) private var settings
    @Environment(AppCoordinator.self) private var coordinator

    private let languages = ["English", "Spanish", "French", "German", "Italian", "Portuguese", "Chinese", "Japanese", "Korean"]
    private let modelSizes = ["tiny.en", "base.en", "small.en", "medium.en", "large-v3"]

    var body: some View {
        @Bindable var s = settings

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                GroupedSettingsSection(title: "Language") {
                    VStack(spacing: 0) {
                        SettingsRowView(icon: "globe", iconColor: ColorTokens.accentBlue, title: "Primary Language") {
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
                            iconColor: ColorTokens.accentGreen,
                            title: "Multilingual Mode",
                            subtitle: "Auto-detect and transcribe multiple languages",
                            isOn: $s.multilingualMode
                        )
                    }
                }

                GroupedSettingsSection(title: "Model") {
                    SettingsRowView(icon: "cpu", iconColor: ColorTokens.accentPurple, title: "Model Size", subtitle: "Larger models are more accurate but slower") {
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
            .padding(.top, Spacing.xxl)
            .padding(.bottom, Spacing.lg)
        }
        .navigationTitle("Language")
        .onChange(of: settings.modelSize) {
            Task { await coordinator.retryModelLoad() }
        }
    }
}
