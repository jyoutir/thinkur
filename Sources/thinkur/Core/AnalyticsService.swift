import Foundation
import SwiftData
import os

@MainActor
final class AnalyticsService: AnalyticsRecording {
    private let container: ModelContainer

    init() {
        let schema = Schema([TranscriptionRecord.self, AppUsageRecord.self, DailyAnalytics.self])
        container = SwiftDataContainerFactory.create(
            name: "analytics",
            schema: schema,
            storeURL: Constants.appSupportDirectory.appendingPathComponent("analytics.store")
        )
    }

    init(container: ModelContainer) {
        self.container = container
    }

    func record(rawText: String, processedText: String, duration: Double, appBundleID: String, appName: String, correctionCount: Int) {
        let context = container.mainContext
        let wordCount = processedText.split(separator: " ").count

        let record = TranscriptionRecord(
            rawText: rawText,
            processedText: processedText,
            duration: duration,
            appBundleID: appBundleID,
            appName: appName,
            correctionCount: correctionCount
        )
        context.insert(record)

        let bundleID = appBundleID
        let predicate = #Predicate<AppUsageRecord> { $0.bundleID == bundleID }
        let descriptor = FetchDescriptor<AppUsageRecord>(predicate: predicate)

        if let existing = try? context.fetch(descriptor).first {
            existing.totalTranscriptions += 1
            existing.totalWords += wordCount
            existing.totalDuration += duration
            existing.lastUsed = .now
        } else {
            let usage = AppUsageRecord(bundleID: appBundleID, appName: appName)
            usage.totalTranscriptions = 1
            usage.totalWords = wordCount
            usage.totalDuration = duration
            context.insert(usage)
        }

        let today = DailyAnalytics.todayString()
        let dailyPredicate = #Predicate<DailyAnalytics> { $0.dateString == today }
        let dailyDescriptor = FetchDescriptor<DailyAnalytics>(predicate: dailyPredicate)

        if let existing = try? context.fetch(dailyDescriptor).first {
            existing.transcriptionCount += 1
            existing.totalWords += wordCount
            existing.totalDuration += duration
        } else {
            let daily = DailyAnalytics(dateString: today)
            daily.transcriptionCount = 1
            daily.totalWords = wordCount
            daily.totalDuration = duration
            context.insert(daily)
        }

        do {
            try context.save()
            Logger.analytics.debug("Recorded transcription: \(wordCount) words, \(String(format: "%.1f", duration))s")
        } catch {
            Logger.analytics.error("Failed to save analytics: \(error)")
        }
    }

    // MARK: - Query Methods

    func fetchTotalTimeSaved() async -> TimeInterval {
        let context = container.mainContext
        let descriptor = FetchDescriptor<DailyAnalytics>()
        guard let records = try? context.fetch(descriptor) else { return 0 }
        let totalDuration = records.reduce(0.0) { $0 + $1.totalDuration }
        return totalDuration * 2.3 // typing multiplier
    }

    func fetchTotalWords() async -> Int {
        let context = container.mainContext
        let descriptor = FetchDescriptor<DailyAnalytics>()
        guard let records = try? context.fetch(descriptor) else { return 0 }
        return records.reduce(0) { $0 + $1.totalWords }
    }

    func fetchTotalSessions() async -> Int {
        let context = container.mainContext
        let descriptor = FetchDescriptor<DailyAnalytics>()
        guard let records = try? context.fetch(descriptor) else { return 0 }
        return records.reduce(0) { $0 + $1.transcriptionCount }
    }

    func fetchDailyAnalytics(for period: InsightsPeriod) async -> [DailyAnalytics] {
        let context = container.mainContext
        let cutoff = Calendar.current.date(byAdding: .day, value: -period.days, to: .now) ?? .now
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let cutoffString = formatter.string(from: cutoff)

        let predicate = #Predicate<DailyAnalytics> { $0.dateString >= cutoffString }
        var descriptor = FetchDescriptor<DailyAnalytics>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.dateString)]
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchTopApps(limit: Int = 5) async -> [AppUsageRecord] {
        let context = container.mainContext
        var descriptor = FetchDescriptor<AppUsageRecord>()
        descriptor.sortBy = [SortDescriptor(\.totalWords, order: .reverse)]
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchRecentTranscriptions(limit: Int = 10) async -> [TranscriptionRecord] {
        let context = container.mainContext
        var descriptor = FetchDescriptor<TranscriptionRecord>()
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchTranscriptions(since days: Int, limit: Int = 200) async -> [TranscriptionRecord] {
        let context = container.mainContext
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let predicate = #Predicate<TranscriptionRecord> { $0.timestamp >= cutoff }
        var descriptor = FetchDescriptor<TranscriptionRecord>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchActiveDateStrings(since days: Int) async -> Set<String> {
        let context = container.mainContext
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let cutoffString = formatter.string(from: cutoff)
        let predicate = #Predicate<DailyAnalytics> { $0.dateString >= cutoffString }
        let descriptor = FetchDescriptor<DailyAnalytics>(predicate: predicate)
        guard let records = try? context.fetch(descriptor) else { return [] }
        return Set(records.map(\.dateString))
    }

    func clearAllHistory() async throws {
        let context = container.mainContext
        try context.delete(model: TranscriptionRecord.self)
        try context.delete(model: AppUsageRecord.self)
        try context.delete(model: DailyAnalytics.self)
        try context.save()
        Logger.analytics.info("All analytics history cleared")
    }
}
