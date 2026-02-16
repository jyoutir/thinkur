import Foundation

struct TranscriptionGroup: Identifiable {
    let id: String        // "2026-02-16"
    let title: String     // "Today", "Yesterday", "Monday, Feb 14"
    let records: [TranscriptionRecord]
}

@MainActor
@Observable
final class HomeViewModel {
    var groupedTranscriptions: [TranscriptionGroup] = []
    var activeDateStrings: Set<String> = []
    var selectedDay: Date?

    private var allRecords: [TranscriptionRecord] = []
    private let analyticsService: AnalyticsService

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

    init(analyticsService: AnalyticsService) {
        self.analyticsService = analyticsService
    }

    func loadData() async {
        allRecords = await analyticsService.fetchTranscriptions(since: 30)
        activeDateStrings = await analyticsService.fetchActiveDateStrings(since: 30)
        rebuildGroups()
    }

    func selectDay(_ day: Date?) {
        selectedDay = day
        rebuildGroups()
    }

    private func rebuildGroups() {
        let calendar = Calendar.current
        let records: [TranscriptionRecord]

        if let day = selectedDay {
            records = allRecords.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
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
