import SwiftUI

struct StyleView: View {
    @Environment(StyleViewModel.self) private var viewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Adapt your voice typing style for each application.")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)

                GroupedSettingsSection(title: "Per-App Styles") {
                    VStack(spacing: 0) {
                        ForEach(viewModel.stylePreferences) { entry in
                            StyleAppRow(entry: entry) { newStyle in
                                Task { await viewModel.updateStyle(for: entry.id, style: newStyle) }
                            }
                            if entry.id != viewModel.stylePreferences.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding(Spacing.lg)
        }
        .navigationTitle("Style")
        .task {
            await viewModel.loadData()
        }
    }
}
