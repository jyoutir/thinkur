import Foundation

@MainActor
protocol AnalyticsRecording {
    func record(rawText: String, processedText: String, duration: Double, appBundleID: String, appName: String, correctionCount: Int)
    func fetchTranscriptions(since days: Int, limit: Int) async -> [TranscriptionRecord]
    func fetchActiveDateStrings(since days: Int) async -> Set<String>
    func fetchTotalTimeSaved() async -> TimeInterval
    func fetchTotalWords() async -> Int
    func fetchTotalSessions() async -> Int
    func fetchDailyAnalytics(for period: InsightsPeriod) async -> [DailyAnalytics]
    func fetchTopApps(limit: Int) async -> [AppUsageRecord]
}

extension AnalyticsRecording {
    func fetchTranscriptions(since days: Int) async -> [TranscriptionRecord] {
        await fetchTranscriptions(since: days, limit: 200)
    }

    func fetchTopApps() async -> [AppUsageRecord] {
        await fetchTopApps(limit: 5)
    }
}
