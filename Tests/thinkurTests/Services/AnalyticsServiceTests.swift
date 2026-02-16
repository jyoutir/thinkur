import Testing
import SwiftData
@testable import thinkur

@Suite("AnalyticsService", .serialized)
struct AnalyticsServiceTests {
    @MainActor
    private func makeService() -> AnalyticsService {
        let schema = Schema([TranscriptionRecord.self, AppUsageRecord.self, DailyAnalytics.self])
        let container = SwiftDataContainerFactory.createInMemory(schema: schema)
        return AnalyticsService(container: container)
    }

    @Test @MainActor func recordCreatesRecords() async {
        let service = makeService()
        service.record(
            rawText: "hello world",
            processedText: "Hello world.",
            duration: 2.0,
            appBundleID: "com.test.app",
            appName: "TestApp"
        )
        let words = await service.fetchTotalWords()
        #expect(words == 2)

        let sessions = await service.fetchTotalSessions()
        #expect(sessions == 1)
    }

    @Test @MainActor func fetchTotalTimeSaved() async {
        let service = makeService()
        service.record(
            rawText: "test",
            processedText: "test",
            duration: 10.0,
            appBundleID: "com.test",
            appName: "Test"
        )
        let timeSaved = await service.fetchTotalTimeSaved()
        // 10.0 * 2.3 = 23.0
        #expect(timeSaved == 23.0)
    }

    @Test @MainActor func fetchTopAppsSortsByWordCount() async {
        let service = makeService()
        service.record(
            rawText: "a", processedText: "a", duration: 1.0,
            appBundleID: "com.app1", appName: "App1"
        )
        service.record(
            rawText: "one two three four five",
            processedText: "one two three four five",
            duration: 1.0,
            appBundleID: "com.app2", appName: "App2"
        )
        let topApps = await service.fetchTopApps(limit: 5)
        #expect(topApps.count == 2)
        #expect(topApps.first?.bundleID == "com.app2")
    }

    @Test @MainActor func clearAllHistoryDeletesEverything() async throws {
        let service = makeService()
        service.record(
            rawText: "test", processedText: "test", duration: 1.0,
            appBundleID: "com.test", appName: "Test"
        )
        try await service.clearAllHistory()
        let words = await service.fetchTotalWords()
        #expect(words == 0)
        let sessions = await service.fetchTotalSessions()
        #expect(sessions == 0)
    }

    @Test @MainActor func multipleRecordsAccumulate() async {
        let service = makeService()
        service.record(
            rawText: "hello", processedText: "hello", duration: 1.0,
            appBundleID: "com.test", appName: "Test"
        )
        service.record(
            rawText: "world", processedText: "world", duration: 2.0,
            appBundleID: "com.test", appName: "Test"
        )
        let sessions = await service.fetchTotalSessions()
        #expect(sessions == 2)
        let words = await service.fetchTotalWords()
        #expect(words == 2)
    }
}
