import SwiftUI

struct StyleView: View {
    @Environment(StyleViewModel.self) private var viewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("Adapt your voice typing style for each application.")
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textTertiary)

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
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .navigationTitle("Style")
        .task {
            await viewModel.loadData()
        }
    }
}
