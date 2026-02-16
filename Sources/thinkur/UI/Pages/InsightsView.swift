import SwiftUI

struct InsightsView: View {
    @Environment(InsightsViewModel.self) private var viewModel

    var body: some View {
        @Bindable var vm = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
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
                    StatCardView(
                        title: "Total Words",
                        value: "\(viewModel.totalWords)",
                        unit: "words"
                    )
                    StatCardView(
                        title: "Sessions",
                        value: "\(viewModel.totalSessions)",
                        unit: "total"
                    )
                }

                // Chart
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Daily Activity")
                        .font(Typography.title3)
                        .foregroundStyle(ColorTokens.textPrimary)

                    if viewModel.chartData.isEmpty {
                        Text("No data for this period.")
                            .font(Typography.body)
                            .foregroundStyle(ColorTokens.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, Spacing.xl)
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
                        Text("No app usage data yet.")
                            .font(Typography.body)
                            .foregroundStyle(ColorTokens.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, Spacing.lg)
                    } else {
                        let totalWords = viewModel.topApps.reduce(0) { $0 + $1.totalWords }
                        VStack(spacing: Spacing.xs) {
                            ForEach(viewModel.topApps, id: \.bundleID) { app in
                                AppUsageRow(
                                    appName: app.appName,
                                    percentage: totalWords > 0 ? Double(app.totalWords) / Double(totalWords) * 100 : 0,
                                    wordCount: app.totalWords
                                )
                            }
                        }
                        .padding(Spacing.md)
                        .glassCard()
                    }
                }
            }
            .padding(Spacing.lg)
        }
        .navigationTitle("Insights")
        .task {
            await viewModel.loadData()
        }
    }
}
