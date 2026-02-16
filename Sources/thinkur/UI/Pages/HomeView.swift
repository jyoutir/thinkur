import SwiftUI

struct HomeView: View {
    @Environment(HomeViewModel.self) private var viewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Press Tab prompt
                HStack(spacing: Spacing.sm) {
                    Text("Press")
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.textSecondary)
                    KeyboardShortcutBadge(key: "Tab")
                    Text("to start voice typing")
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(Spacing.md)
                .glassCard()

                // Recent transcriptions
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Recent Activity")
                        .font(Typography.title3)
                        .foregroundStyle(ColorTokens.textPrimary)

                    if viewModel.recentTranscriptions.isEmpty {
                        Text("No transcriptions yet. Press Tab to start dictating.")
                            .font(Typography.body)
                            .foregroundStyle(ColorTokens.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, Spacing.xl)
                    } else {
                        ForEach(viewModel.recentTranscriptions, id: \.timestamp) { record in
                            TranscriptRowView(
                                appName: record.appName,
                                appBundleID: record.appBundleID,
                                timestamp: record.timestamp,
                                preview: record.processedText
                            )
                            .padding(Spacing.sm)
                            .glassCard()
                        }
                    }
                }
            }
            .padding(Spacing.lg)
        }
        .navigationTitle("Home")
        .task {
            await viewModel.loadData()
        }
    }

}
