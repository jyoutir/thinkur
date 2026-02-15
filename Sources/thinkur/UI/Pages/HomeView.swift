import SwiftUI

struct HomeView: View {
    @Environment(HomeViewModel.self) private var viewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Stat cards
                HStack(spacing: Spacing.md) {
                    StatCardView(
                        title: "Time Saved",
                        value: viewModel.timeSavedFormatted,
                        unit: "total"
                    )

                    StatCardView(
                        title: "Words Dictated",
                        value: formatNumber(viewModel.wordsDictated),
                        unit: "words"
                    )

                    StatCardView(
                        title: "Sessions",
                        value: "\(viewModel.totalSessions)",
                        unit: "total"
                    )
                }

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
                        VStack(spacing: 0) {
                            ForEach(viewModel.recentTranscriptions, id: \.timestamp) { record in
                                TranscriptRowView(
                                    appName: record.appName,
                                    timestamp: record.timestamp,
                                    preview: record.processedText,
                                    appColor: colorForApp(record.appName)
                                )
                                if record.timestamp != viewModel.recentTranscriptions.last?.timestamp {
                                    Divider().padding(.leading, 40)
                                }
                            }
                        }
                        .padding(Spacing.sm)
                        .glassCard()
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

    private func formatNumber(_ n: Int) -> String {
        if n >= 1000 {
            return String(format: "%.1fk", Double(n) / 1000.0)
        }
        return "\(n)"
    }

    private func colorForApp(_ name: String) -> Color {
        switch name.lowercased() {
        case let n where n.contains("slack"): return ColorTokens.accentPurple
        case let n where n.contains("mail"): return ColorTokens.accentOrange
        case let n where n.contains("note"): return ColorTokens.accentYellow
        case let n where n.contains("xcode"): return ColorTokens.accentBlue
        case let n where n.contains("chrome"): return ColorTokens.accentRed
        default: return ColorTokens.accentBlue
        }
    }
}
