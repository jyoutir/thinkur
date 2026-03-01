import FluidAudio
import Foundation
import os

/// Represents a transcribed segment attributed to a speaker.
struct AttributedSegment: Sendable {
    let speakerId: String
    let text: String
    let startTime: Double
    let endTime: Double
}

/// Merges ASR token timings with speaker diarization using a WhisperX-aligned pipeline:
/// tokens -> words (BPE reconstruction) -> phrase grouping -> per-phrase speaker assignment.
///
/// Unlike word-level assignment (which can clip words onto the wrong speaker at boundaries),
/// phrase-level assignment queries the interval tree with the full phrase time range and picks
/// the speaker with maximum overlap. This naturally prevents mid-sentence splits.
enum MeetingTranscriptionMerger {

    /// Gap threshold for splitting words into phrases (seconds).
    /// Tighter than the old 1.0s sentence threshold — captures speaker turns without punctuation.
    private static let phraseGapThreshold: Double = 0.5

    /// Reconstruct words from BPE tokens, group into phrases, then assign
    /// a single speaker per phrase via interval tree overlap.
    static func mergeTimingsWithSpeakers(
        tokenTimings: [TokenTiming],
        speakerSegments: [TimedSpeakerSegment],
        chunkStartTime: Double
    ) -> [AttributedSegment] {
        guard !tokenTimings.isEmpty, !speakerSegments.isEmpty else { return [] }

        // Step 1: BPE tokens -> whole words
        let words = WordReconstructor.reconstruct(
            tokens: tokenTimings,
            chunkStartTime: chunkStartTime
        )
        guard !words.isEmpty else { return [] }

        // Step 2: Group words into phrases (split at punctuation or timing gaps)
        let phrases = groupIntoPhrases(words)

        // Step 3: Assign one speaker per phrase via interval tree overlap
        let entries = speakerSegments.map { seg in
            IntervalTree<String>.Entry(
                start: Double(seg.startTimeSeconds),
                end: Double(seg.endTimeSeconds),
                value: seg.speakerId
            )
        }
        let tree = IntervalTree(entries)

        return phrases.compactMap { phrase -> AttributedSegment? in
            guard !phrase.isEmpty else { return nil }
            let speaker = assignPhraseSpeaker(
                phrase: phrase, tree: tree, fallbackSpeaker: speakerSegments[0].speakerId
            )
            let text = phrase.map(\.text).joined(separator: " ")
                .trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return nil }
            return AttributedSegment(
                speakerId: speaker,
                text: text,
                startTime: phrase[0].start,
                endTime: phrase[phrase.count - 1].end
            )
        }
    }

    // MARK: - Phrase Grouping

    /// Splits words into phrases at sentence-ending punctuation (`.?!`) or timing gaps > threshold.
    private static func groupIntoPhrases(_ words: [ReconstructedWord]) -> [[ReconstructedWord]] {
        guard !words.isEmpty else { return [] }

        var phrases: [[ReconstructedWord]] = []
        var current: [ReconstructedWord] = [words[0]]

        for i in 1..<words.count {
            let prevText = words[i - 1].text
            let gap = words[i].start - words[i - 1].end

            let sentenceEnd = prevText.hasSuffix(".") || prevText.hasSuffix("?") || prevText.hasSuffix("!")
            let longGap = gap > phraseGapThreshold

            if sentenceEnd || longGap {
                phrases.append(current)
                current = [words[i]]
            } else {
                current.append(words[i])
            }
        }
        phrases.append(current)

        return phrases
    }

    // MARK: - Per-Phrase Speaker Assignment

    /// Queries the interval tree with the phrase's full [start, end] range,
    /// sums overlap duration per speaker, and returns the speaker with maximum overlap.
    /// Falls back to nearest segment if no overlap found.
    private static func assignPhraseSpeaker(
        phrase: [ReconstructedWord],
        tree: IntervalTree<String>,
        fallbackSpeaker: String
    ) -> String {
        let phraseStart = phrase[0].start
        let phraseEnd = phrase[phrase.count - 1].end

        let overlaps = tree.query(start: phraseStart, end: phraseEnd)

        if overlaps.isEmpty {
            let phraseMid = (phraseStart + phraseEnd) / 2.0
            return tree.findNearest(time: phraseMid)?.value ?? fallbackSpeaker
        }

        // Sum overlap duration per speaker
        var speakerOverlap: [String: Double] = [:]
        for entry in overlaps {
            let oStart = max(phraseStart, entry.start)
            let oEnd = min(phraseEnd, entry.end)
            let duration = max(0, oEnd - oStart)
            speakerOverlap[entry.value, default: 0] += duration
        }

        // Pick speaker with maximum total overlap
        return speakerOverlap.max(by: { $0.value < $1.value })?.key ?? fallbackSpeaker
    }
}
