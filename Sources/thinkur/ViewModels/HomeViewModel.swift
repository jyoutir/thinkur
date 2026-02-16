import Foundation

@MainActor
@Observable
final class HomeViewModel {
    var timeSaved: TimeInterval = 0
    var wordsDictated: Int = 0
    var totalSessions: Int = 0
    var recentTranscriptions: [TranscriptionRecord] = []

    private let analyticsService: AnalyticsService

    init(analyticsService: AnalyticsService) {
        self.analyticsService = analyticsService
    }

    func loadData() async {
        timeSaved = await analyticsService.fetchTotalTimeSaved()
        wordsDictated = await analyticsService.fetchTotalWords()
        totalSessions = await analyticsService.fetchTotalSessions()
        recentTranscriptions = await analyticsService.fetchRecentTranscriptions(limit: 5)
    }

    var timeSavedFormatted: String {
        Formatters.formatTimeSaved(timeSaved)
    }
}
