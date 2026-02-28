import Foundation
import os

@MainActor
@Observable
final class MeetingViewModel {
    var meetings: [MeetingRecord] = []
    var selectedMeeting: MeetingRecord?

    let coordinator: MeetingCoordinator
    private let meetingService: MeetingService
    private let speakerProfileService: SpeakerProfileService

    init(coordinator: MeetingCoordinator, meetingService: MeetingService, speakerProfileService: SpeakerProfileService) {
        self.coordinator = coordinator
        self.meetingService = meetingService
        self.speakerProfileService = speakerProfileService
    }

    func loadMeetings() {
        do {
            meetings = try meetingService.fetchMeetings()
        } catch {
            Logger.app.error("Failed to fetch meetings: \(error)")
        }
    }

    func deleteMeeting(_ meeting: MeetingRecord) {
        do {
            try meetingService.deleteMeeting(meeting)
            if selectedMeeting?.id == meeting.id {
                selectedMeeting = nil
            }
            loadMeetings()
        } catch {
            Logger.app.error("Failed to delete meeting: \(error)")
        }
    }

    func updateSpeakerName(meeting: MeetingRecord, speakerId: String, name: String) {
        do {
            try meetingService.updateSpeakerName(meeting: meeting, speakerId: speakerId, name: name)
            // Also update the speaker profile so the name carries to future meetings
            if let profile = try speakerProfileService.findProfile(
                for: speakerId,
                embeddings: meeting.speakerEmbeddings
            ) {
                try speakerProfileService.updateProfileName(profile, name: name)
            }
        } catch {
            Logger.app.error("Failed to update speaker name: \(error)")
        }
    }

    func updateTitle(meeting: MeetingRecord, title: String) {
        do {
            try meetingService.updateTitle(meeting: meeting, title: title)
        } catch {
            Logger.app.error("Failed to update meeting title: \(error)")
        }
    }

    func startMeeting() async {
        await coordinator.startMeeting()
    }

    func stopMeeting() async {
        await coordinator.stopMeeting()
        loadMeetings()
        // Auto-select the most recent meeting after processing completes
        if coordinator.processingState == .complete {
            selectedMeeting = meetings.first
        }
    }
}
