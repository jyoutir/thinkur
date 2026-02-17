import Foundation
@testable import thinkur

@MainActor
final class MockAnalyticsRecording: AnalyticsRecording {
    var recordedEntries: [(rawText: String, processedText: String, duration: Double, appBundleID: String, appName: String, correctionCount: Int)] = []
    var transcriptionsToReturn: [TranscriptionRecord] = []
    var activeDateStringsToReturn: Set<String> = []
    var totalTimeSavedToReturn: TimeInterval = 0
    var totalWordsToReturn: Int = 0
    var totalSessionsToReturn: Int = 0
    var dailyAnalyticsToReturn: [DailyAnalytics] = []
    var topAppsToReturn: [AppUsageRecord] = []

    func record(rawText: String, processedText: String, duration: Double, appBundleID: String, appName: String, correctionCount: Int) {
        recordedEntries.append((rawText, processedText, duration, appBundleID, appName, correctionCount))
    }

    func fetchTranscriptions(since days: Int, limit: Int) async -> [TranscriptionRecord] {
        transcriptionsToReturn
    }

    func fetchActiveDateStrings(since days: Int) async -> Set<String> {
        activeDateStringsToReturn
    }

    func fetchTotalTimeSaved() async -> TimeInterval {
        totalTimeSavedToReturn
    }

    func fetchTotalWords() async -> Int {
        totalWordsToReturn
    }

    func fetchTotalSessions() async -> Int {
        totalSessionsToReturn
    }

    func fetchDailyAnalytics(for period: InsightsPeriod) async -> [DailyAnalytics] {
        dailyAnalyticsToReturn
    }

    func fetchTopApps(limit: Int) async -> [AppUsageRecord] {
        topAppsToReturn
    }
}
