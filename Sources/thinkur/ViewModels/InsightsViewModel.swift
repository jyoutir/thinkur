import Foundation

@MainActor
@Observable
final class InsightsViewModel {
    var selectedPeriod: InsightsPeriod = .sevenDays
    var dailyAnalytics: [DailyAnalytics] = []
    var topApps: [AppUsageRecord] = []
    var totalTimeSaved: TimeInterval = 0
    var totalWords: Int = 0
    var totalSessions: Int = 0

    private let analyticsService: AnalyticsService

    init(analyticsService: AnalyticsService) {
        self.analyticsService = analyticsService
    }

    func loadData() async {
        totalTimeSaved = await analyticsService.fetchTotalTimeSaved()
        totalWords = await analyticsService.fetchTotalWords()
        totalSessions = await analyticsService.fetchTotalSessions()
        dailyAnalytics = await analyticsService.fetchDailyAnalytics(for: selectedPeriod)
        topApps = await analyticsService.fetchTopApps(limit: 5)
    }

    var timeSavedFormatted: String {
        Formatters.formatTimeSaved(totalTimeSaved)
    }
}
