import Foundation

enum TimeFilter: String, CaseIterable {
    case today = "Today"
    case week = "This Week"
    case month = "This Month"
    case all = "All"
}

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
    var displayedMonth: Date = .now

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
        allRecords = await analyticsService.fetchTranscriptions(since: 30, limit: 5000)
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

    /// Range selection: first click sets start, second sets end, third clears and starts fresh
    func selectDate(_ day: Date) {
        let calendar = Calendar.current
        activeFilter = .all

        if rangeStart != nil, rangeEnd != nil {
            // Both set — clear and start fresh
            rangeStart = day
            rangeEnd = nil
        } else if let start = rangeStart {
            // Only start set
            if calendar.isDate(day, inSameDayAs: start) {
                // Same day — clear
                rangeStart = nil
            } else {
                // Different day — set range, ensure start ≤ end
                if day < start {
                    rangeStart = day
                    rangeEnd = start
                } else {
                    rangeEnd = day
                }
            }
        } else {
            // Nothing selected — set start
            rangeStart = day
        }

        rebuildGroups()
    }

    var activeFilter: TimeFilter = .all

    func applyFilter(_ filter: TimeFilter) {
        if activeFilter == filter {
            activeFilter = .all
        } else {
            activeFilter = filter
        }

        let calendar = Calendar.current
        switch activeFilter {
        case .today:
            rangeStart = calendar.startOfDay(for: Date())
            rangeEnd = nil
        case .week:
            rangeStart = calendar.date(byAdding: .day, value: -7, to: Date())
            rangeEnd = Date()
        case .month:
            rangeStart = calendar.date(byAdding: .month, value: -1, to: Date())
            rangeEnd = Date()
        case .all:
            rangeStart = nil
            rangeEnd = nil
        }
        rebuildGroups()
    }

    func clearFilter() {
        activeFilter = .all
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

    func monthChanged() {
        if rangeStart == nil && rangeEnd == nil {
            rebuildGroups()
        }
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
            // No selection — filter to displayed month
            let components = calendar.dateComponents([.year, .month], from: displayedMonth)
            guard let monthStart = calendar.date(from: components),
                  let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                records = allRecords
                return
            }
            records = allRecords.filter { $0.timestamp >= monthStart && $0.timestamp < monthEnd }
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
