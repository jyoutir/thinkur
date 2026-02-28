import FluidAudio

struct SpeakerWord {
    let text: String
    let start: Double
    let end: Double
    let speakerId: String
    let confidence: Float
}

/// Assigns speaker IDs to words based on diarization segment overlap,
/// then smooths boundary noise with stickiness and isolated-flip correction.
enum SpeakerAssignment {
    private static let stickinessThreshold: Double = 0.3
    private static let isolatedFlipThreshold: Double = 0.5

    /// Mutable candidate used during the two-phase assignment.
    private struct Candidate {
        let text: String
        let start: Double
        let end: Double
        var speakerId: String
        let confidence: Float
        /// 0.0 = tie between top two overlaps, 1.0 = single overlap or nearest fallback.
        let overlapMargin: Double
        /// The second-best speaker when multiple overlaps exist; nil otherwise.
        let runnerUpSpeaker: String?
    }

    static func assignSpeakers(
        words: [ReconstructedWord],
        speakerSegments: [TimedSpeakerSegment]
    ) -> [SpeakerWord] {
        guard !words.isEmpty else { return [] }
        guard !speakerSegments.isEmpty else {
            return words.map { SpeakerWord(
                text: $0.text, start: $0.start, end: $0.end,
                speakerId: "unknown", confidence: $0.confidence
            ) }
        }

        let entries = speakerSegments.map { seg in
            IntervalTree<String>.Entry(
                start: Double(seg.startTimeSeconds),
                end: Double(seg.endTimeSeconds),
                value: seg.speakerId
            )
        }
        let tree = IntervalTree(entries)

        // Phase 1: initial assignment with overlap margins
        var candidates = initialAssignment(
            words: words, tree: tree, speakerSegments: speakerSegments
        )

        // Phase 2: smooth boundaries
        applyStickiness(&candidates)
        fixIsolatedFlips(&candidates)

        return candidates.map {
            SpeakerWord(
                text: $0.text, start: $0.start, end: $0.end,
                speakerId: $0.speakerId, confidence: $0.confidence
            )
        }
    }

    // MARK: - Phase 1

    private static func initialAssignment(
        words: [ReconstructedWord],
        tree: IntervalTree<String>,
        speakerSegments: [TimedSpeakerSegment]
    ) -> [Candidate] {
        words.map { word in
            let overlaps = tree.query(start: word.start, end: word.end)

            if overlaps.isEmpty {
                let wordMid = (word.start + word.end) / 2.0
                let nearest = tree.findNearest(time: wordMid)
                return Candidate(
                    text: word.text, start: word.start, end: word.end,
                    speakerId: nearest?.value ?? speakerSegments[0].speakerId,
                    confidence: word.confidence,
                    overlapMargin: 1.0,
                    runnerUpSpeaker: nil
                )
            }

            if overlaps.count == 1 {
                return Candidate(
                    text: word.text, start: word.start, end: word.end,
                    speakerId: overlaps[0].value,
                    confidence: word.confidence,
                    overlapMargin: 1.0,
                    runnerUpSpeaker: nil
                )
            }

            // Multiple overlaps — compute overlap durations and find top two
            var overlapDurations: [(speaker: String, duration: Double)] = []
            for entry in overlaps {
                let oStart = max(word.start, entry.start)
                let oEnd = min(word.end, entry.end)
                let duration = max(0, oEnd - oStart)
                overlapDurations.append((entry.value, duration))
            }
            overlapDurations.sort { $0.duration > $1.duration }

            let bestSpeaker = overlapDurations[0].speaker
            let bestDuration = overlapDurations[0].duration
            let secondDuration = overlapDurations[1].duration
            let margin = bestDuration > 0
                ? (bestDuration - secondDuration) / bestDuration
                : 0.0
            let runnerUp = overlapDurations[1].speaker

            return Candidate(
                text: word.text, start: word.start, end: word.end,
                speakerId: bestSpeaker,
                confidence: word.confidence,
                overlapMargin: margin,
                runnerUpSpeaker: runnerUp
            )
        }
    }

    // MARK: - Phase 2a: Speaker stickiness

    /// When overlap margin is low and the previous word's speaker matches the
    /// runner-up, keep the previous speaker to avoid noisy flips at boundaries.
    private static func applyStickiness(_ candidates: inout [Candidate]) {
        for i in 1..<candidates.count {
            guard candidates[i].overlapMargin < stickinessThreshold,
                  let runnerUp = candidates[i].runnerUpSpeaker,
                  candidates[i - 1].speakerId == runnerUp
            else { continue }
            candidates[i].speakerId = candidates[i - 1].speakerId
        }
    }

    // MARK: - Phase 2b: Isolated flip correction

    /// If a single word differs from both neighbours (who agree on the same
    /// speaker) and its overlap margin is low, flip it to match neighbours.
    private static func fixIsolatedFlips(_ candidates: inout [Candidate]) {
        guard candidates.count >= 3 else { return }
        for i in 1..<(candidates.count - 1) {
            let prev = candidates[i - 1].speakerId
            let curr = candidates[i].speakerId
            let next = candidates[i + 1].speakerId
            guard curr != prev, prev == next,
                  candidates[i].overlapMargin < isolatedFlipThreshold
            else { continue }
            candidates[i].speakerId = prev
        }
    }
}
