import FluidAudio

struct SpeakerWord {
    let text: String
    let start: Double
    let end: Double
    let speakerId: String
    let confidence: Float
}

/// Assigns speaker IDs to words based on diarization segment overlap.
/// Ported from WhisperX diarize.py assign_word_speakers().
enum SpeakerAssignment {
    static func assignSpeakers(
        words: [ReconstructedWord],
        speakerSegments: [TimedSpeakerSegment]
    ) -> [SpeakerWord] {
        guard !words.isEmpty else { return [] }
        guard !speakerSegments.isEmpty else {
            // No speaker segments — assign all to default
            return words.map { SpeakerWord(
                text: $0.text, start: $0.start, end: $0.end,
                speakerId: "unknown", confidence: $0.confidence
            ) }
        }

        // Build interval tree from speaker segments
        let entries = speakerSegments.map { seg in
            IntervalTree<String>.Entry(
                start: Double(seg.startTimeSeconds),
                end: Double(seg.endTimeSeconds),
                value: seg.speakerId
            )
        }
        let tree = IntervalTree(entries)

        return words.map { word in
            let overlaps = tree.query(start: word.start, end: word.end)

            if overlaps.isEmpty {
                // fill_nearest: find nearest speaker segment by midpoint distance
                let wordMid = (word.start + word.end) / 2.0
                let nearest = tree.findNearest(time: wordMid)
                return SpeakerWord(
                    text: word.text, start: word.start, end: word.end,
                    speakerId: nearest?.value ?? speakerSegments[0].speakerId,
                    confidence: word.confidence
                )
            }

            if overlaps.count == 1 {
                return SpeakerWord(
                    text: word.text, start: word.start, end: word.end,
                    speakerId: overlaps[0].value,
                    confidence: word.confidence
                )
            }

            // Multiple overlaps — pick speaker with maximum overlap duration
            var bestSpeaker = overlaps[0].value
            var bestOverlap: Double = 0

            for entry in overlaps {
                let overlapStart = max(word.start, entry.start)
                let overlapEnd = min(word.end, entry.end)
                let overlap = max(0, overlapEnd - overlapStart)
                if overlap > bestOverlap {
                    bestOverlap = overlap
                    bestSpeaker = entry.value
                }
            }

            return SpeakerWord(
                text: word.text, start: word.start, end: word.end,
                speakerId: bestSpeaker,
                confidence: word.confidence
            )
        }
    }
}
