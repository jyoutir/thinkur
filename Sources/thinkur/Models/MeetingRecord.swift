import Foundation
import SwiftData

@Model
final class MeetingRecord {
    var title: String
    var date: Date
    var duration: Double
    var speakerCount: Int
    var audioFileRelativePath: String?
    var speakerNamesData: Data?

    @Relationship(deleteRule: .cascade, inverse: \MeetingSegment.meeting)
    var segments: [MeetingSegment] = []

    init(
        title: String = "Meeting",
        date: Date = Date(),
        duration: Double = 0,
        speakerCount: Int = 0,
        audioFileRelativePath: String? = nil
    ) {
        self.title = title
        self.date = date
        self.duration = duration
        self.speakerCount = speakerCount
        self.audioFileRelativePath = audioFileRelativePath
    }

    // MARK: - Speaker Names

    var speakerNames: [String: String] {
        get {
            guard let data = speakerNamesData else { return [:] }
            return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }
        set {
            speakerNamesData = try? JSONEncoder().encode(newValue)
        }
    }

    func displayName(for speakerId: String) -> String {
        speakerNames[speakerId] ?? "Speaker \(speakerId)"
    }

    // MARK: - Audio File

    var audioFileURL: URL? {
        guard let path = audioFileRelativePath else { return nil }
        return Constants.appSupportDirectory
            .appendingPathComponent("meetings", isDirectory: true)
            .appendingPathComponent(path)
    }

    // MARK: - Sorted Segments

    var sortedSegments: [MeetingSegment] {
        segments.sorted { $0.startTime < $1.startTime }
    }
}
