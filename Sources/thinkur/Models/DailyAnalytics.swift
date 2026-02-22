import Foundation
import SwiftData

@Model
final class DailyAnalytics {
    @Attribute(.unique) var dateString: String
    var transcriptionCount: Int
    var totalWords: Int
    var totalDuration: Double

    init(dateString: String) {
        self.dateString = dateString
        self.transcriptionCount = 0
        self.totalWords = 0
        self.totalDuration = 0
    }

    static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: .now)
    }
}
