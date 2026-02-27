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

/// Processes audio chunks: runs ASR for text + diarization for speaker labels,
/// then merges word timings with speaker segments.
actor MeetingTranscriptionPipeline {
    private let asrManager: AsrManager
    private let diarizerManager: DiarizerManager

    init(asrManager: AsrManager, diarizerManager: DiarizerManager) {
        self.asrManager = asrManager
        self.diarizerManager = diarizerManager
    }

    /// Process a chunk of audio and return speaker-attributed segments.
    /// - Parameters:
    ///   - samples: Audio samples (16kHz mono Float32)
    ///   - chunkStartTime: The absolute start time of this chunk in the meeting
    /// - Returns: Array of attributed segments with speaker IDs and text
    func processChunk(_ samples: [Float], chunkStartTime: Double) async -> [AttributedSegment] {
        guard samples.count > Int(Constants.sampleRate * 0.5) else { return [] }

        // Run ASR
        let asrResult: (text: String, timings: [TokenTiming]?)
        do {
            let result = try await asrManager.transcribe(samples, source: .microphone)
            asrResult = (result.text, result.tokenTimings)
        } catch {
            Logger.transcription.error("Meeting ASR failed: \(error)")
            return []
        }

        let text = asrResult.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }

        // Run diarization
        let diarizationSegments: [TimedSpeakerSegment]
        do {
            let result = try diarizerManager.performCompleteDiarization(
                samples,
                sampleRate: Int(Constants.sampleRate),
                atTime: chunkStartTime
            )
            diarizationSegments = result.segments
        } catch {
            Logger.app.error("Meeting diarization failed: \(error)")
            // Fall back to a single unknown speaker segment
            return [AttributedSegment(
                speakerId: "1",
                text: text,
                startTime: chunkStartTime,
                endTime: chunkStartTime + Double(samples.count) / Constants.sampleRate
            )]
        }

        guard !diarizationSegments.isEmpty else {
            return [AttributedSegment(
                speakerId: "1",
                text: text,
                startTime: chunkStartTime,
                endTime: chunkStartTime + Double(samples.count) / Constants.sampleRate
            )]
        }

        // Merge word timings with speaker segments
        guard let tokenTimings = asrResult.timings, !tokenTimings.isEmpty else {
            // No word-level timings — assign all text to the dominant speaker
            let dominantSpeaker = diarizationSegments
                .max(by: { $0.durationSeconds < $1.durationSeconds })?
                .speakerId ?? "1"
            return [AttributedSegment(
                speakerId: dominantSpeaker,
                text: text,
                startTime: chunkStartTime,
                endTime: chunkStartTime + Double(samples.count) / Constants.sampleRate
            )]
        }

        return Self.mergeTimingsWithSpeakers(
            tokenTimings: tokenTimings,
            speakerSegments: diarizationSegments,
            chunkStartTime: chunkStartTime
        )
    }

    /// Map each token to its overlapping speaker segment, then group consecutive
    /// same-speaker tokens into attributed segments.
    static func mergeTimingsWithSpeakers(
        tokenTimings: [TokenTiming],
        speakerSegments: [TimedSpeakerSegment],
        chunkStartTime: Double
    ) -> [AttributedSegment] {
        // For each token, find the speaker segment that overlaps most
        var tokenSpeakers: [(token: String, speakerId: String, start: Double, end: Double)] = []

        for timing in tokenTimings {
            let tokenStart = chunkStartTime + timing.startTime
            let tokenEnd = chunkStartTime + timing.endTime
            let tokenMid = (tokenStart + tokenEnd) / 2.0

            // Find the speaker segment whose time range contains the token midpoint
            var bestSpeaker = speakerSegments.first?.speakerId ?? "1"
            var bestOverlap: Double = -1

            for seg in speakerSegments {
                let segStart = Double(seg.startTimeSeconds)
                let segEnd = Double(seg.endTimeSeconds)
                let overlapStart = max(tokenStart, segStart)
                let overlapEnd = min(tokenEnd, segEnd)
                let overlap = max(0, overlapEnd - overlapStart)

                if overlap > bestOverlap {
                    bestOverlap = overlap
                    bestSpeaker = seg.speakerId
                } else if overlap == 0 && bestOverlap <= 0 {
                    // No overlap — use closest segment by midpoint
                    let dist = min(abs(tokenMid - segStart), abs(tokenMid - segEnd))
                    let bestDist = bestOverlap < 0 ? Double.infinity : 0
                    if dist < bestDist {
                        bestSpeaker = seg.speakerId
                    }
                }
            }

            tokenSpeakers.append((timing.token, bestSpeaker, tokenStart, tokenEnd))
        }

        // Group consecutive same-speaker tokens
        var result: [AttributedSegment] = []
        var currentSpeaker = ""
        var currentWords: [String] = []
        var currentStart: Double = 0
        var currentEnd: Double = 0

        for item in tokenSpeakers {
            if item.speakerId != currentSpeaker {
                if !currentWords.isEmpty {
                    result.append(AttributedSegment(
                        speakerId: currentSpeaker,
                        text: currentWords.joined(separator: "").trimmingCharacters(in: .whitespaces),
                        startTime: currentStart,
                        endTime: currentEnd
                    ))
                }
                currentSpeaker = item.speakerId
                currentWords = [item.token]
                currentStart = item.start
                currentEnd = item.end
            } else {
                currentWords.append(item.token)
                currentEnd = item.end
            }
        }

        if !currentWords.isEmpty {
            result.append(AttributedSegment(
                speakerId: currentSpeaker,
                text: currentWords.joined(separator: "").trimmingCharacters(in: .whitespaces),
                startTime: currentStart,
                endTime: currentEnd
            ))
        }

        return result.filter { !$0.text.isEmpty }
    }
}
