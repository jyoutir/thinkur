import Foundation
import SwiftData

@Model
final class MeetingSegment {
    var speakerId: String
    var text: String
    var startTime: Double
    var endTime: Double
    var meeting: MeetingRecord?

    init(
        speakerId: String,
        text: String,
        startTime: Double,
        endTime: Double
    ) {
        self.speakerId = speakerId
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
    }

    var duration: Double {
        endTime - startTime
    }

    var formattedStartTime: String {
        Self.formatTime(startTime)
    }

    static func formatTime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
