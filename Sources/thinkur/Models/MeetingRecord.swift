import Foundation
import SwiftData

@Model
final class MeetingRecord {
    var title: String
    var date: Date
    var duration: Double
    var speakerCount: Int
    var audioFileRelativePath: String?
    var micAudioRelativePath: String?
    var systemAudioRelativePath: String?
    var speakerNamesData: Data?
    var speakerEmbeddingsData: Data?

    @Relationship(deleteRule: .cascade, inverse: \MeetingSegment.meeting)
    var segments: [MeetingSegment] = []

    init(
        title: String = "Meeting",
        date: Date = Date(),
        duration: Double = 0,
        speakerCount: Int = 0,
        audioFileRelativePath: String? = nil,
        micAudioRelativePath: String? = nil,
        systemAudioRelativePath: String? = nil
    ) {
        self.title = title
        self.date = date
        self.duration = duration
        self.speakerCount = speakerCount
        self.audioFileRelativePath = audioFileRelativePath
        self.micAudioRelativePath = micAudioRelativePath
        self.systemAudioRelativePath = systemAudioRelativePath
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
        if let customName = speakerNames[speakerId] {
            return customName
        }
        switch speakerId {
        case "local":
            return "You"
        case _ where speakerId.hasPrefix("remote-"):
            let suffix = speakerId.dropFirst("remote-".count)
            return "Speaker \(suffix)"
        default:
            // Backward compat for old numeric IDs
            return "Speaker \(speakerId)"
        }
    }

    // MARK: - Speaker Embeddings

    var speakerEmbeddings: [String: [Float]] {
        get {
            guard let data = speakerEmbeddingsData else { return [:] }
            return (try? JSONDecoder().decode([String: [Float]].self, from: data)) ?? [:]
        }
        set {
            speakerEmbeddingsData = try? JSONEncoder().encode(newValue)
        }
    }

    // MARK: - Audio Files

    var audioFileURL: URL? {
        guard let path = audioFileRelativePath else { return nil }
        return Constants.appSupportDirectory
            .appendingPathComponent("meetings", isDirectory: true)
            .appendingPathComponent(path)
    }

    var micAudioFileURL: URL? {
        guard let path = micAudioRelativePath else { return nil }
        return Constants.appSupportDirectory
            .appendingPathComponent("meetings", isDirectory: true)
            .appendingPathComponent(path)
    }

    var systemAudioFileURL: URL? {
        guard let path = systemAudioRelativePath else { return nil }
        return Constants.appSupportDirectory
            .appendingPathComponent("meetings", isDirectory: true)
            .appendingPathComponent(path)
    }

    // MARK: - Sorted Segments

    var sortedSegments: [MeetingSegment] {
        segments.sorted { $0.startTime < $1.startTime }
    }
}
