import Foundation
import SwiftData

@Model
final class SpeakerProfile {
    var profileId: String
    var name: String
    var embeddingData: Data?
    var meetingCount: Int
    var lastSeen: Date
    var createdAt: Date

    init(
        profileId: String = UUID().uuidString,
        name: String = "",
        embedding: [Float]? = nil,
        meetingCount: Int = 1,
        lastSeen: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.profileId = profileId
        self.name = name
        self.embeddingData = embedding.flatMap { try? JSONEncoder().encode($0) }
        self.meetingCount = meetingCount
        self.lastSeen = lastSeen
        self.createdAt = createdAt
    }

    var embedding: [Float]? {
        get {
            guard let data = embeddingData else { return nil }
            return try? JSONDecoder().decode([Float].self, from: data)
        }
        set {
            embeddingData = newValue.flatMap { try? JSONEncoder().encode($0) }
        }
    }
}
