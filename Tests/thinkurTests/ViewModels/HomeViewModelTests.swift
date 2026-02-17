import Testing
import Foundation
@testable import thinkur

@Suite("HomeViewModel")
struct HomeViewModelTests {

    // MARK: - Helpers

    @MainActor
    private func makeViewModel(records: [TranscriptionRecord] = [], activeDates: Set<String> = []) -> (MockAnalyticsRecording, HomeViewModel) {
        let mock = MockAnalyticsRecording()
        mock.transcriptionsToReturn = records
        mock.activeDateStringsToReturn = activeDates
        let vm = HomeViewModel(analyticsService: mock)
        return (mock, vm)
    }

    private func makeRecord(text: String, daysAgo: Int, appName: String = "Notes") -> TranscriptionRecord {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
        return TranscriptionRecord(
            rawText: text,
            processedText: text,
            duration: 2.0,
            timestamp: date,
            appBundleID: "com.apple.Notes",
            appName: appName
        )
    }

    // MARK: - Loading

    @Test @MainActor func loadDataPopulatesGroups() async {
        let (_, vm) = makeViewModel(records: [
            makeRecord(text: "hello", daysAgo: 0),
            makeRecord(text: "world", daysAgo: 0),
            makeRecord(text: "yesterday", daysAgo: 1),
        ])

        await vm.loadData()

        #expect(vm.groupedTranscriptions.count == 2)
        // Today's group should have 2 records
        let todayGroup = vm.groupedTranscriptions.first { $0.title == "Today" }
        #expect(todayGroup?.records.count == 2)
        // Yesterday's group should have 1 record
        let yesterdayGroup = vm.groupedTranscriptions.first { $0.title == "Yesterday" }
        #expect(yesterdayGroup?.records.count == 1)
    }

    @Test @MainActor func loadDataSetsActiveDateStrings() async {
        let activeDates: Set<String> = ["2026-02-15", "2026-02-16"]
        let (_, vm) = makeViewModel(activeDates: activeDates)

        await vm.loadData()

        #expect(vm.activeDateStrings == activeDates)
    }

    @Test @MainActor func emptyDataShowsNoGroups() async {
        let (_, vm) = makeViewModel()

        await vm.loadData()

        #expect(vm.groupedTranscriptions.isEmpty)
    }

    // MARK: - Date Filtering

    @Test @MainActor func selectDateFiltersSingleDay() async {
        let today = Calendar.current.startOfDay(for: .now)
        let (_, vm) = makeViewModel(records: [
            makeRecord(text: "today", daysAgo: 0),
            makeRecord(text: "yesterday", daysAgo: 1),
        ])

        await vm.loadData()
        #expect(vm.groupedTranscriptions.count == 2)

        vm.selectDate(today)
        #expect(vm.groupedTranscriptions.count == 1)
        #expect(vm.groupedTranscriptions.first?.title == "Today")
        #expect(vm.rangeStart != nil)
        #expect(vm.rangeEnd == nil)
    }

    @Test @MainActor func selectDateRangeFiltersTwoDays() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let (_, vm) = makeViewModel(records: [
            makeRecord(text: "today", daysAgo: 0),
            makeRecord(text: "yesterday", daysAgo: 1),
            makeRecord(text: "old", daysAgo: 3),
        ])

        await vm.loadData()
        #expect(vm.groupedTranscriptions.count == 3)

        // Select range: yesterday to today
        vm.selectDate(yesterday)
        vm.selectDate(today)
        #expect(vm.rangeStart != nil)
        #expect(vm.rangeEnd != nil)
        #expect(vm.groupedTranscriptions.count == 2)
    }

    @Test @MainActor func clearFilterShowsAllRecords() async {
        let today = Calendar.current.startOfDay(for: .now)
        let (_, vm) = makeViewModel(records: [
            makeRecord(text: "today", daysAgo: 0),
            makeRecord(text: "yesterday", daysAgo: 1),
        ])

        await vm.loadData()
        vm.selectDate(today)
        #expect(vm.groupedTranscriptions.count == 1)

        vm.clearFilter()
        #expect(vm.groupedTranscriptions.count == 2)
        #expect(vm.rangeStart == nil)
        #expect(vm.rangeEnd == nil)
    }

    @Test @MainActor func tappingSameDateClearsFilter() async {
        let today = Calendar.current.startOfDay(for: .now)
        let (_, vm) = makeViewModel(records: [
            makeRecord(text: "today", daysAgo: 0),
            makeRecord(text: "yesterday", daysAgo: 1),
        ])

        await vm.loadData()
        vm.selectDate(today)
        #expect(vm.rangeStart != nil)

        // Tap same date again — should clear
        vm.selectDate(today)
        #expect(vm.rangeStart == nil)
        #expect(vm.groupedTranscriptions.count == 2)
    }

    // MARK: - Filter Description

    @Test @MainActor func filterDescriptionNilWhenNoFilter() async {
        let (_, vm) = makeViewModel()
        await vm.loadData()
        #expect(vm.filterDescription == nil)
    }

    @Test @MainActor func filterDescriptionShowsSingleDate() async {
        let today = Calendar.current.startOfDay(for: .now)
        let (_, vm) = makeViewModel(records: [makeRecord(text: "hello", daysAgo: 0)])

        await vm.loadData()
        vm.selectDate(today)
        #expect(vm.filterDescription != nil)
    }

    // MARK: - Group Collapsing

    @Test @MainActor func toggleGroupCollapsesAndExpands() async {
        let (_, vm) = makeViewModel(records: [makeRecord(text: "hello", daysAgo: 0)])

        await vm.loadData()
        let groupID = vm.groupedTranscriptions.first!.id

        #expect(!vm.collapsedGroups.contains(groupID))

        vm.toggleGroup(groupID)
        #expect(vm.collapsedGroups.contains(groupID))

        vm.toggleGroup(groupID)
        #expect(!vm.collapsedGroups.contains(groupID))
    }

    // MARK: - Date Range Swap

    @Test @MainActor func selectDateAutoSwapsWhenEndBeforeStart() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let (_, vm) = makeViewModel(records: [
            makeRecord(text: "today", daysAgo: 0),
            makeRecord(text: "old", daysAgo: 2),
        ])

        await vm.loadData()

        // Select today first, then 2 days ago — should auto-swap
        vm.selectDate(today)
        vm.selectDate(twoDaysAgo)

        #expect(vm.rangeStart != nil)
        #expect(vm.rangeEnd != nil)
        // Start should be the earlier date
        #expect(calendar.isDate(vm.rangeStart!, inSameDayAs: twoDaysAgo))
        #expect(calendar.isDate(vm.rangeEnd!, inSameDayAs: today))
    }

    // MARK: - Grouping Order

    @Test @MainActor func groupsAreSortedNewestFirst() async {
        let (_, vm) = makeViewModel(records: [
            makeRecord(text: "old", daysAgo: 3),
            makeRecord(text: "today", daysAgo: 0),
            makeRecord(text: "yesterday", daysAgo: 1),
        ])

        await vm.loadData()

        #expect(vm.groupedTranscriptions.count == 3)
        #expect(vm.groupedTranscriptions[0].title == "Today")
        #expect(vm.groupedTranscriptions[1].title == "Yesterday")
    }
}
