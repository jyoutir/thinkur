import Foundation
import SwiftData
import os

@MainActor
final class AnalyticsService {
    private let container: ModelContainer

    init() {
        do {
            let schema = Schema([TranscriptionRecord.self, AppUsageRecord.self, DailyAnalytics.self])
            let config = ModelConfiguration(
                "analytics",
                schema: schema,
                url: Constants.appSupportDirectory.appendingPathComponent("analytics.store")
            )
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            Logger.analytics.error("Failed to create ModelContainer: \(error)")
            // Fallback to in-memory store
            do {
                let schema = Schema([TranscriptionRecord.self, AppUsageRecord.self, DailyAnalytics.self])
                let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                container = try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Cannot create even in-memory ModelContainer: \(error)")
            }
        }
    }

    func record(rawText: String, processedText: String, duration: Double, appBundleID: String, appName: String) {
        let context = container.mainContext
        let wordCount = processedText.split(separator: " ").count

        // Insert transcription record
        let record = TranscriptionRecord(
            rawText: rawText,
            processedText: processedText,
            duration: duration,
            appBundleID: appBundleID,
            appName: appName
        )
        context.insert(record)

        // Update app usage
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

        // Update daily analytics
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
}
