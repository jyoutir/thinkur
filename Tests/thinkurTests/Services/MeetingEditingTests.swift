import Foundation
import Testing
import SwiftData
@testable import thinkur

@Suite("Meeting Editing", .serialized)
struct MeetingEditingTests {

    // MARK: - Helpers

    @MainActor
    private func makeService() -> MeetingService {
        let schema = Schema([MeetingRecord.self, MeetingSegment.self])
        let container = SwiftDataContainerFactory.createInMemory(schema: schema)
        return MeetingService(container: container)
    }

    @MainActor
    private func makeMeeting(service: MeetingService, title: String = "Standup") throws -> MeetingRecord {
        try service.saveMeeting(
            title: title,
            duration: 120,
            speakerCount: 2,
            audioRelativePath: nil,
            segments: [
                AttributedSegment(speakerId: "local", text: "Hello everyone", startTime: 0, endTime: 2),
                AttributedSegment(speakerId: "remote-1", text: "Hey!", startTime: 2, endTime: 3),
            ]
        )
    }

    // MARK: - Title Editing

    @Test @MainActor func updateTitlePersists() throws {
        let service = makeService()
        let meeting = try makeMeeting(service: service)
        #expect(meeting.title == "Standup")

        try service.updateTitle(meeting: meeting, title: "Weekly Sync")
        #expect(meeting.title == "Weekly Sync")

        // Verify it survives a re-fetch
        let fetched = try service.fetchMeetings()
        #expect(fetched.count == 1)
        #expect(fetched.first?.title == "Weekly Sync")
    }

    @Test @MainActor func directTitleMutationWorks() throws {
        let service = makeService()
        let meeting = try makeMeeting(service: service)

        // Simulate @Bindable: mutate the model property directly
        meeting.title = "Renamed"
        #expect(meeting.title == "Renamed")

        // Verify the change is visible on re-fetch (autosave in-memory)
        let fetched = try service.fetchMeetings()
        #expect(fetched.first?.title == "Renamed")
    }

    @Test @MainActor func titleCanBeSetToEmptyString() throws {
        let service = makeService()
        let meeting = try makeMeeting(service: service)

        meeting.title = ""
        #expect(meeting.title == "")
    }

    @Test @MainActor func titleCanBeSetMultipleTimes() throws {
        let service = makeService()
        let meeting = try makeMeeting(service: service)

        // Simulate rapid typing: each character changes the title
        meeting.title = "A"
        meeting.title = "AB"
        meeting.title = "ABC"
        #expect(meeting.title == "ABC")
    }

    // MARK: - Speaker Name Editing

    @Test @MainActor func updateSpeakerNamePersists() throws {
        let service = makeService()
        let meeting = try makeMeeting(service: service)
        #expect(meeting.displayName(for: "local") == "You")
        #expect(meeting.displayName(for: "remote-1") == "Speaker 1")

        try service.updateSpeakerName(meeting: meeting, speakerId: "local", name: "Alice")
        #expect(meeting.displayName(for: "local") == "Alice")

        try service.updateSpeakerName(meeting: meeting, speakerId: "remote-1", name: "Bob")
        #expect(meeting.displayName(for: "remote-1") == "Bob")

        // Verify re-fetch
        let fetched = try service.fetchMeetings()
        #expect(fetched.first?.displayName(for: "local") == "Alice")
        #expect(fetched.first?.displayName(for: "remote-1") == "Bob")
    }

    @Test @MainActor func directSpeakerNameMutationWorks() throws {
        let service = makeService()
        let meeting = try makeMeeting(service: service)

        // Simulate @Bindable: mutate the computed property directly
        var names = meeting.speakerNames
        names["local"] = "Me"
        meeting.speakerNames = names
        #expect(meeting.displayName(for: "local") == "Me")

        // Simulate per-keystroke binding: repeated mutations
        names = meeting.speakerNames
        names["remote-1"] = "B"
        meeting.speakerNames = names

        names = meeting.speakerNames
        names["remote-1"] = "Bo"
        meeting.speakerNames = names

        names = meeting.speakerNames
        names["remote-1"] = "Bob"
        meeting.speakerNames = names

        #expect(meeting.displayName(for: "remote-1") == "Bob")
    }

    @Test @MainActor func speakerNamesJsonRoundTrips() throws {
        let service = makeService()
        let meeting = try makeMeeting(service: service)

        // Start with no custom names
        #expect(meeting.speakerNames.isEmpty)

        // Set names
        meeting.speakerNames = ["local": "Alice", "remote-1": "Bob"]
        #expect(meeting.speakerNames["local"] == "Alice")
        #expect(meeting.speakerNames["remote-1"] == "Bob")

        // Verify the backing data is valid JSON
        #expect(meeting.speakerNamesData != nil)
        let decoded = try JSONDecoder().decode([String: String].self, from: meeting.speakerNamesData!)
        #expect(decoded == ["local": "Alice", "remote-1": "Bob"])
    }

    // MARK: - Segments & Relationships

    @Test @MainActor func meetingHasCorrectSegments() throws {
        let service = makeService()
        let meeting = try makeMeeting(service: service)

        #expect(meeting.segments.count == 2)
        let sorted = meeting.sortedSegments
        #expect(sorted[0].speakerId == "local")
        #expect(sorted[0].text == "Hello everyone")
        #expect(sorted[1].speakerId == "remote-1")
        #expect(sorted[1].text == "Hey!")
    }

    @Test @MainActor func displayNameFallbacksWork() throws {
        let service = makeService()
        let meeting = try makeMeeting(service: service)

        // Default display names before any customization
        #expect(meeting.displayName(for: "local") == "You")
        #expect(meeting.displayName(for: "remote-1") == "Speaker 1")
        #expect(meeting.displayName(for: "remote-2") == "Speaker 2")

        // Custom name overrides default
        var names = meeting.speakerNames
        names["local"] = "Alice"
        meeting.speakerNames = names
        #expect(meeting.displayName(for: "local") == "Alice")
        // Other speakers still use defaults
        #expect(meeting.displayName(for: "remote-1") == "Speaker 1")
    }
}
