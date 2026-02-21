import Foundation

struct TranscriptionGroup: Identifiable {
    let id: String        // "2026-02-16"
    let title: String     // "Today", "Yesterday", "Monday, Feb 14"
    let records: [TranscriptionRecord]
}

@MainActor
@Observable
final class HomeViewModel {
    // Keep observable - these affect UI directly
    var groupedTranscriptions: [TranscriptionGroup] = []
    var collapsedGroups: Set<String> = []
    var rangeStart: Date?
    var rangeEnd: Date?

    // Mark as ignored - changes shouldn't trigger full rebuild
    @ObservationIgnored
    var activeDateStrings: Set<String> = []

    @ObservationIgnored
    var totalTimeSaved: TimeInterval = 0

    @ObservationIgnored
    var totalWords: Int = 0

    @ObservationIgnored
    private var hasSetInitialCollapse = false

    @ObservationIgnored
    private var allRecords: [TranscriptionRecord] = []

    @ObservationIgnored
    private let analyticsService: any AnalyticsRecording

    @ObservationIgnored
    private let sharedState: SharedAppState

    // Computed property - no observation needed
    var transcriptionVersion: Int { sharedState.transcriptionVersion }

    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    private static let shortDisplayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    init(analyticsService: any AnalyticsRecording, sharedState: SharedAppState) {
        self.analyticsService = analyticsService
        self.sharedState = sharedState
    }

    func loadData() async {
        allRecords = await analyticsService.fetchTranscriptions(since: 30)
        activeDateStrings = await analyticsService.fetchActiveDateStrings(since: 30)
        totalTimeSaved = await analyticsService.fetchTotalTimeSaved()
        totalWords = await analyticsService.fetchTotalWords()
        rebuildGroups()

        if !hasSetInitialCollapse {
            hasSetInitialCollapse = true
            let todayKey = Self.dateKeyFormatter.string(from: Date())
            collapsedGroups = Set(
                groupedTranscriptions.map(\.id).filter { $0 != todayKey }
            )
        }
    }

    /// Tap logic: first tap = start, second different day = end, re-tap bound = clear all
    func selectDate(_ day: Date) {
        let calendar = Calendar.current

        if let start = rangeStart, calendar.isDate(day, inSameDayAs: start) {
            // Tapped on start bound — clear filter
            rangeStart = nil
            rangeEnd = nil
        } else if let end = rangeEnd, calendar.isDate(day, inSameDayAs: end) {
            // Tapped on end bound — clear filter
            rangeStart = nil
            rangeEnd = nil
        } else if rangeStart == nil {
            // No selection yet — set start
            rangeStart = day
            rangeEnd = nil
        } else if rangeEnd == nil {
            // Have start, no end — set end (auto-swap if needed)
            let start = rangeStart!
            if day < start {
                rangeStart = day
                rangeEnd = start
            } else {
                rangeEnd = day
            }
        } else {
            // Both set, tapping new day — reset to new single selection
            rangeStart = day
            rangeEnd = nil
        }

        rebuildGroups()
    }

    func clearFilter() {
        rangeStart = nil
        rangeEnd = nil
        rebuildGroups()
    }

    func toggleGroup(_ groupID: String) {
        if collapsedGroups.contains(groupID) {
            collapsedGroups.remove(groupID)
        } else {
            collapsedGroups.insert(groupID)
        }
    }

    var filterDescription: String? {
        guard let start = rangeStart else { return nil }
        let startStr = Self.shortDisplayFormatter.string(from: start)
        if let end = rangeEnd {
            let endStr = Self.shortDisplayFormatter.string(from: end)
            return "\(startStr) – \(endStr)"
        }
        return startStr
    }

    private func rebuildGroups() {
        let calendar = Calendar.current
        let records: [TranscriptionRecord]

        if let start = rangeStart {
            let startOfStart = calendar.startOfDay(for: start)
            if let end = rangeEnd {
                let endOfEnd = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: end)!)
                records = allRecords.filter { $0.timestamp >= startOfStart && $0.timestamp < endOfEnd }
            } else {
                records = allRecords.filter { calendar.isDate($0.timestamp, inSameDayAs: start) }
            }
        } else {
            records = allRecords
        }

        let grouped = Dictionary(grouping: records) { record in
            calendar.startOfDay(for: record.timestamp)
        }

        groupedTranscriptions = grouped.keys.sorted(by: >).map { startOfDay in
            let dateKey = Self.dateKeyFormatter.string(from: startOfDay)
            let title: String
            if calendar.isDateInToday(startOfDay) {
                title = "Today"
            } else if calendar.isDateInYesterday(startOfDay) {
                title = "Yesterday"
            } else {
                title = Self.displayFormatter.string(from: startOfDay)
            }
            return TranscriptionGroup(
                id: dateKey,
                title: title,
                records: grouped[startOfDay]!.sorted { $0.timestamp > $1.timestamp }
            )
        }
    }
}
