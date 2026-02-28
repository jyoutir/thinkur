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

/// Merges ASR token timings with speaker diarization using the WhisperX pipeline:
/// tokens -> words (BPE reconstruction) -> speaker assignment -> sentence grouping.
enum MeetingTranscriptionMerger {

    /// Reconstruct words from BPE tokens, assign speakers via interval overlap,
    /// then group consecutive same-speaker words into sentence segments.
    static func mergeTimingsWithSpeakers(
        tokenTimings: [TokenTiming],
        speakerSegments: [TimedSpeakerSegment],
        chunkStartTime: Double
    ) -> [AttributedSegment] {
        guard !tokenTimings.isEmpty, !speakerSegments.isEmpty else { return [] }

        // Step 1: BPE tokens -> whole words (replaces WhisperX's wav2vec2 alignment)
        let words = WordReconstructor.reconstruct(
            tokens: tokenTimings,
            chunkStartTime: chunkStartTime
        )

        // Step 2: Assign speakers to words (ported from WhisperX diarize.py)
        let speakerWords = SpeakerAssignment.assignSpeakers(
            words: words,
            speakerSegments: speakerSegments
        )

        // Step 3: Group consecutive same-speaker words into sentences
        return groupIntoSentences(speakerWords)
    }

    /// Groups consecutive same-speaker words into sentence segments.
    /// Breaks at sentence-ending punctuation or pauses > 1s between words.
    private static func groupIntoSentences(_ words: [SpeakerWord]) -> [AttributedSegment] {
        guard !words.isEmpty else { return [] }

        var result: [AttributedSegment] = []
        var currentSpeaker = words[0].speakerId
        var currentWords: [String] = [words[0].text]
        var currentStart = words[0].start
        var currentEnd = words[0].end

        for i in 1..<words.count {
            let word = words[i]
            let prevEnd = words[i - 1].end
            let gap = word.start - prevEnd
            let prevText = words[i - 1].text

            // Break on: speaker change, sentence-ending punctuation, or pause > 1s
            let sentenceEnd = prevText.hasSuffix(".") || prevText.hasSuffix("?") || prevText.hasSuffix("!")
            let speakerChange = word.speakerId != currentSpeaker
            let longPause = gap > 1.0

            if speakerChange || sentenceEnd || longPause {
                let text = currentWords.joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                if !text.isEmpty {
                    result.append(AttributedSegment(
                        speakerId: currentSpeaker,
                        text: text,
                        startTime: currentStart,
                        endTime: currentEnd
                    ))
                }
                currentSpeaker = word.speakerId
                currentWords = [word.text]
                currentStart = word.start
                currentEnd = word.end
            } else {
                currentWords.append(word.text)
                currentEnd = word.end
            }
        }

        // Flush last group
        let text = currentWords.joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        if !text.isEmpty {
            result.append(AttributedSegment(
                speakerId: currentSpeaker,
                text: text,
                startTime: currentStart,
                endTime: currentEnd
            ))
        }

        return result
    }
}
