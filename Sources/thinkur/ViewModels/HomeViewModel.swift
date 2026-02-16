import Foundation

@MainActor
@Observable
final class HomeViewModel {
    var recentTranscriptions: [TranscriptionRecord] = []

    private let analyticsService: AnalyticsService

    init(analyticsService: AnalyticsService) {
        self.analyticsService = analyticsService
    }

    func loadData() async {
        recentTranscriptions = await analyticsService.fetchRecentTranscriptions(limit: 5)
    }
}
