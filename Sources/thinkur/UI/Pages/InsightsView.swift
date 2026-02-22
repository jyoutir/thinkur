import SwiftUI

struct InsightsView: View {
    @Environment(InsightsViewModel.self) private var viewModel
    @Environment(SettingsManager.self) private var settings
    @State private var appeared = false

    var body: some View {
        @Bindable var vm = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("Track your dictation usage and productivity.")
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textTertiary)

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
                        unit: "total",

                    )
                    .hoverBrightness()
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(Animations.glassStagger(index: 0), value: appeared)

                    StatCardView(
                        title: "Total Words",
                        value: "\(viewModel.totalWords)",
                        unit: "words",

                    )
                    .hoverBrightness()
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(Animations.glassStagger(index: 1), value: appeared)

                    StatCardView(
                        title: "Sessions",
                        value: "\(viewModel.totalSessions)",
                        unit: "total",

                    )
                    .hoverBrightness()
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(Animations.glassStagger(index: 2), value: appeared)
                }

                // Chart
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Daily Activity")
                        .font(Typography.title3)
                        .foregroundStyle(ColorTokens.textPrimary)

                    if viewModel.chartData.isEmpty {
                        GlassEmptyState(
                            icon: "chart.bar",
                            title: "No data yet",
                            subtitle: "Start dictating to see your insights"
                        )
                    } else {
                        BarChartView(data: viewModel.chartData, barColor: settings.accentUITint)
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
                        GlassEmptyState(
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
                                    wordCount: app.totalWords,
                                    color: settings.accentUITint
                                )
                                .hoverBrightness()
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 8)
                                .animation(Animations.glassStagger(index: index), value: appeared)
                            }
                        }
                        .padding(Spacing.md)
                        .glassCard()
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
        .navigationTitle("Insights")
        .task { await viewModel.loadData() }
        .onAppear { appeared = true }
    }
}
