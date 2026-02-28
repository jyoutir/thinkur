import Accelerate
import Foundation
import SwiftData
import os

@MainActor
final class SpeakerProfileService {
    private let container: ModelContainer

    /// Cosine similarity threshold for matching speakers across meetings.
    private let matchThreshold: Float = 0.75

    init() {
        let schema = Schema([SpeakerProfile.self])
        container = SwiftDataContainerFactory.create(
            name: "speaker-profiles",
            schema: schema,
            storeURL: Constants.appSupportDirectory.appendingPathComponent("speaker-profiles.store")
        )
    }

    init(container: ModelContainer) {
        self.container = container
    }

    // MARK: - Matching

    /// Match speaker embeddings from a meeting against known profiles.
    /// Returns a mapping from meeting speaker ID to matched SpeakerProfile.
    func matchSpeakers(embeddings: [String: [Float]]) throws -> [String: SpeakerProfile] {
        let profiles = try fetchProfiles()
        var matches: [String: SpeakerProfile] = [:]

        for (speakerId, embedding) in embeddings {
            // Skip "local" — the user is always "You"
            guard speakerId != "local" else { continue }

            var bestProfile: SpeakerProfile?
            var bestScore: Float = matchThreshold

            for profile in profiles {
                guard let profileEmb = profile.embedding else { continue }
                let score = cosineSimilarity(embedding, profileEmb)
                if score > bestScore {
                    bestScore = score
                    bestProfile = profile
                }
            }

            if let profile = bestProfile {
                matches[speakerId] = profile
            }
        }

        return matches
    }

    /// Create or update profiles based on meeting results.
    /// - Parameters:
    ///   - embeddings: Speaker embeddings from the meeting
    ///   - matches: Previously matched profiles (from `matchSpeakers`)
    func updateProfiles(
        embeddings: [String: [Float]],
        matches: [String: SpeakerProfile]
    ) throws {
        let context = container.mainContext

        for (speakerId, embedding) in embeddings {
            guard speakerId != "local" else { continue }

            if let existing = matches[speakerId] {
                // Update existing profile
                existing.meetingCount += 1
                existing.lastSeen = Date()
            } else {
                // Create new profile for unmatched speaker
                let profile = SpeakerProfile(embedding: embedding)
                context.insert(profile)
            }
        }

        try context.save()
    }

    /// Apply matched profile names to a meeting's speaker names.
    /// Returns the names mapping to use for the meeting.
    func applyProfileNames(
        matches: [String: SpeakerProfile]
    ) -> [String: String] {
        var names: [String: String] = [:]
        for (speakerId, profile) in matches {
            if !profile.name.isEmpty {
                names[speakerId] = profile.name
            }
        }
        return names
    }

    // MARK: - CRUD

    func fetchProfiles() throws -> [SpeakerProfile] {
        let descriptor = FetchDescriptor<SpeakerProfile>(
            sortBy: [SortDescriptor(\.lastSeen, order: .reverse)]
        )
        return try container.mainContext.fetch(descriptor)
    }

    func updateProfileName(_ profile: SpeakerProfile, name: String) throws {
        profile.name = name
        try container.mainContext.save()
    }

    /// Find the profile that matches a speaker embedding from a specific meeting.
    func findProfile(for speakerId: String, embeddings: [String: [Float]]) throws -> SpeakerProfile? {
        guard let embedding = embeddings[speakerId] else { return nil }
        let profiles = try fetchProfiles()

        var bestProfile: SpeakerProfile?
        var bestScore: Float = matchThreshold

        for profile in profiles {
            guard let profileEmb = profile.embedding else { continue }
            let score = cosineSimilarity(embedding, profileEmb)
            if score > bestScore {
                bestScore = score
                bestProfile = profile
            }
        }

        return bestProfile
    }

    // MARK: - Cosine Similarity

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        let count = vDSP_Length(a.count)

        vDSP_dotpr(a, 1, b, 1, &dotProduct, count)
        vDSP_dotpr(a, 1, a, 1, &normA, count)
        vDSP_dotpr(b, 1, b, 1, &normB, count)

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0 }

        return dotProduct / denominator
    }
}
