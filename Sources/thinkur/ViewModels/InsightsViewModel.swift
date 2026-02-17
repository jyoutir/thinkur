import Foundation

@MainActor
@Observable
final class InsightsViewModel {
    var selectedPeriod: InsightsPeriod = .sevenDays
    var chartData: [(label: String, value: Double)] = []
    var topApps: [AppUsageRecord] = []
    var totalTimeSaved: TimeInterval = 0
    var totalWords: Int = 0
    var totalSessions: Int = 0

    private let analyticsService: any AnalyticsRecording

    init(analyticsService: any AnalyticsRecording) {
        self.analyticsService = analyticsService
    }

    func loadData() async {
        totalTimeSaved = await analyticsService.fetchTotalTimeSaved()
        totalWords = await analyticsService.fetchTotalWords()
        totalSessions = await analyticsService.fetchTotalSessions()
        let rawAnalytics = await analyticsService.fetchDailyAnalytics(for: selectedPeriod)
        topApps = await analyticsService.fetchTopApps(limit: 5)
        chartData = buildChartData(from: rawAnalytics)
    }

    var timeSavedFormatted: String {
        Formatters.formatTimeSaved(totalTimeSaved)
    }

    /// Fills in every day in the selected period so the chart always shows the full range.
    private func buildChartData(from analytics: [DailyAnalytics]) -> [(label: String, value: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let days = selectedPeriod.days

        let dataFormatter = DateFormatter()
        dataFormatter.dateFormat = "yyyy-MM-dd"

        let labelFormatter = DateFormatter()
        // Short labels: "Mon 16" style for 7d, just day number for 30d
        labelFormatter.dateFormat = days <= 14 ? "EEE" : "d"

        let dataByDate = Dictionary(uniqueKeysWithValues: analytics.map { ($0.dateString, $0.totalWords) })

        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -(days - 1 - offset), to: today) else { return nil }
            let key = dataFormatter.string(from: date)
            let label = labelFormatter.string(from: date)
            let value = Double(dataByDate[key] ?? 0)
            return (label: label, value: value)
        }
    }
}
