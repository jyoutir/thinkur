import Foundation
import SwiftData
import os

@MainActor
final class MeetingService {
    private let container: ModelContainer

    init() {
        let schema = Schema([MeetingRecord.self, MeetingSegment.self])
        container = SwiftDataContainerFactory.create(
            name: "meetings",
            schema: schema,
            storeURL: Constants.appSupportDirectory.appendingPathComponent("meetings.store")
        )
    }

    init(container: ModelContainer) {
        self.container = container
    }

    // MARK: - CRUD

    func saveMeeting(
        title: String,
        duration: Double,
        speakerCount: Int,
        audioRelativePath: String?,
        segments: [AttributedSegment]
    ) throws -> MeetingRecord {
        let context = container.mainContext

        let record = MeetingRecord(
            title: title,
            date: Date(),
            duration: duration,
            speakerCount: speakerCount,
            audioFileRelativePath: audioRelativePath
        )
        context.insert(record)

        for seg in segments {
            let segment = MeetingSegment(
                speakerId: seg.speakerId,
                text: seg.text,
                startTime: seg.startTime,
                endTime: seg.endTime
            )
            segment.meeting = record
            context.insert(segment)
        }

        try context.save()
        Logger.app.info("Saved meeting '\(title)' with \(segments.count) segments")
        return record
    }

    func fetchMeetings() throws -> [MeetingRecord] {
        let descriptor = FetchDescriptor<MeetingRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try container.mainContext.fetch(descriptor)
    }

    func deleteMeeting(_ meeting: MeetingRecord) throws {
        // Clean up audio file
        if let path = meeting.audioFileRelativePath {
            MeetingAudioWriter.deleteAudioFile(relativePath: path)
        }

        let context = container.mainContext
        context.delete(meeting)
        try context.save()
        Logger.app.info("Deleted meeting '\(meeting.title)'")
    }

    func updateSpeakerName(meeting: MeetingRecord, speakerId: String, name: String) throws {
        var names = meeting.speakerNames
        names[speakerId] = name
        meeting.speakerNames = names
        try container.mainContext.save()
    }

    func updateTitle(meeting: MeetingRecord, title: String) throws {
        meeting.title = title
        try container.mainContext.save()
    }
}
