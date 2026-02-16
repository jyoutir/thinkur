import SwiftUI

struct InsightsView: View {
    @Environment(InsightsViewModel.self) private var viewModel
    @State private var appeared = false

    var body: some View {
        @Bindable var vm = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                // Period picker
                Picker("Period", selection: $vm.selectedPeriod) {
                    ForEach(InsightsPeriod.allCases) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .onChange(of: viewModel.selectedPeriod) {
                    Task { await viewModel.loadData() }
                }

                // Stats
                HStack(spacing: Spacing.md) {
                    StatCardView(
                        title: "Time Saved",
                        value: viewModel.timeSavedFormatted,
                        unit: "total"
                    )
                    .hoverBrightness()
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(0.0), value: appeared)

                    StatCardView(
                        title: "Total Words",
                        value: "\(viewModel.totalWords)",
                        unit: "words"
                    )
                    .hoverBrightness()
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(0.05), value: appeared)

                    StatCardView(
                        title: "Sessions",
                        value: "\(viewModel.totalSessions)",
                        unit: "total"
                    )
                    .hoverBrightness()
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(0.1), value: appeared)
                }

                // Chart
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Daily Activity")
                        .font(Typography.title3)
                        .foregroundStyle(ColorTokens.textPrimary)

                    if viewModel.chartData.isEmpty {
                        emptyState(
                            icon: "chart.bar",
                            title: "No data yet",
                            subtitle: "Start dictating to see your insights"
                        )
                    } else {
                        BarChartView(data: viewModel.chartData)
                            .padding(Spacing.md)
                            .glassCard()
                    }
                }

                // Top Apps
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Top Apps")
                        .font(Typography.title3)
                        .foregroundStyle(ColorTokens.textPrimary)

                    if viewModel.topApps.isEmpty {
                        emptyState(
                            icon: "app.dashed",
                            title: "No app usage yet",
                            subtitle: "Start dictating to see your top apps"
                        )
                    } else {
                        let totalWords = viewModel.topApps.reduce(0) { $0 + $1.totalWords }
                        VStack(spacing: Spacing.xs) {
                            ForEach(Array(viewModel.topApps.enumerated()), id: \.element.bundleID) { index, app in
                                AppUsageRow(
                                    appName: app.appName,
                                    bundleID: app.bundleID,
                                    percentage: totalWords > 0 ? Double(app.totalWords) / Double(totalWords) * 100 : 0,
                                    wordCount: app.totalWords
                                )
                                .hoverBrightness()
                                .opacity(appeared ? 1 : 0)
                                .animation(.easeOut(duration: 0.3).delay(Double(index) * 0.05), value: appeared)
                            }
                        }
                        .padding(Spacing.md)
                        .glassCard()
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.xxl)
            .padding(.bottom, Spacing.lg)
        }
        .navigationTitle("Insights")
        .task {
            await viewModel.loadData()
            appeared = true
        }
    }

    @ViewBuilder
    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(ColorTokens.textTertiary.opacity(0.5))

            Text(title)
                .font(Typography.headline)
                .foregroundStyle(ColorTokens.textSecondary)

            Text(subtitle)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }
}
