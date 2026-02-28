/// Final-only meeting processing pipeline.
///
/// After recording stops, both WAV tracks (mic + system) are transcribed in parallel via ASrManager.
/// The system track is run through OfflineDiarizerManager to identify distinct remote speakers.
/// ASR token timings are merged with diarization speaker segments to produce speaker-attributed text.
/// For 1:1 calls (single remote speaker), the merge step is skipped for cleaner output.

import Accelerate
import AVFoundation
import FluidAudio
import Foundation
import os

/// Result of final meeting processing after recording stops.
struct MeetingProcessingResult: Sendable {
    let segments: [AttributedSegment]
    let speakerCount: Int
    let speakerEmbeddings: [String: [Float]]
}

/// Processes mic and system audio tracks after recording stops.
/// Transcribes both tracks in parallel, runs diarization on the system track,
/// and merges everything into speaker-attributed segments.
actor MeetingFinalProcessor {
    nonisolated(unsafe) private let asrManager: AsrManager
    private let offlineDiarizer: OfflineDiarizerManager?

    init(asrManager: AsrManager, offlineDiarizer: OfflineDiarizerManager?) {
        self.asrManager = asrManager
        self.offlineDiarizer = offlineDiarizer
    }

    func process(micURL: URL, systemURL: URL, duration: TimeInterval) async throws -> MeetingProcessingResult {
        // Transcribe both tracks in parallel
        // AsrManager has separate decoder states for .microphone and .system sources
        async let micResult = asrManager.transcribe(micURL, source: .microphone)
        async let sysResult = asrManager.transcribe(systemURL, source: .system)

        let (mic, sys) = try await (micResult, sysResult)

        Logger.app.info("MeetingFinalProcessor: mic=\(mic.text.count) chars, sys=\(sys.text.count) chars")

        // Build local speaker segments from mic tokens
        var localSegments: [AttributedSegment] = []
        if let timings = mic.tokenTimings, !timings.isEmpty {
            localSegments = groupTokens(timings, speakerId: "local", startOffset: 0)
        } else if !mic.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            localSegments = [AttributedSegment(
                speakerId: "local",
                text: mic.text.trimmingCharacters(in: .whitespacesAndNewlines),
                startTime: 0,
                endTime: duration
            )]
        }

        // Build remote speaker segments
        var remoteSegments: [AttributedSegment] = []
        var speakerEmbeddings: [String: [Float]] = [:]

        // Check if system audio actually contains non-silent audio before diarization
        let systemHasContent = hasAudioContent(systemURL)

        if !systemHasContent {
            Logger.app.warning("MeetingFinalProcessor: system audio is silent — skipping diarization")
            // Still use ASR text if available (might have picked up faint audio)
            remoteSegments = makeFallbackRemoteSegments(sys: sys, duration: duration)
        } else if let diarizer = offlineDiarizer {
            do {
                let diarizationResult = try await diarizer.process(systemURL)
                let uniqueRawSpeakers = Set(diarizationResult.segments.map(\.speakerId))
                Logger.app.info("MeetingFinalProcessor: diarizer returned \(diarizationResult.segments.count) segments, \(uniqueRawSpeakers.count) unique speakers: \(uniqueRawSpeakers)")

                // Remap diarizer speaker IDs ("S1", "S2", ...) → "remote-1", "remote-2", ...
                let remappedSegments = remapSpeakerIds(diarizationResult.segments)

                // Only use fallback when diarization produced NO segments at all
                if remappedSegments.isEmpty {
                    Logger.app.info("MeetingFinalProcessor: no diarization segments — using fallback")
                    remoteSegments = makeFallbackRemoteSegments(sys: sys, duration: duration)
                } else if let sysTimings = sys.tokenTimings, !sysTimings.isEmpty {
                    remoteSegments = MeetingTranscriptionMerger.mergeTimingsWithSpeakers(
                        tokenTimings: sysTimings,
                        speakerSegments: remappedSegments,
                        chunkStartTime: 0
                    )
                } else {
                    // No token timings — use diarization segments with system text
                    remoteSegments = remappedSegments.map { seg in
                        AttributedSegment(
                            speakerId: seg.speakerId,
                            text: "",
                            startTime: Double(seg.startTimeSeconds),
                            endTime: Double(seg.endTimeSeconds)
                        )
                    }.filter { !$0.text.isEmpty }

                    // Fallback: assign all system text to dominant remote speaker
                    if remoteSegments.isEmpty, !sys.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let dominantSpeaker = remappedSegments
                            .max(by: { $0.durationSeconds < $1.durationSeconds })?
                            .speakerId ?? "remote-1"
                        remoteSegments = [AttributedSegment(
                            speakerId: dominantSpeaker,
                            text: sys.text.trimmingCharacters(in: .whitespacesAndNewlines),
                            startTime: 0,
                            endTime: duration
                        )]
                    }
                }

                // Extract speaker embeddings from diarization result
                if let db = diarizationResult.speakerDatabase {
                    // Remap the speaker database keys to match our remapped IDs
                    let speakerIdMap = buildSpeakerIdMap(diarizationResult.segments)
                    for (originalId, embedding) in db {
                        let remappedId = speakerIdMap[originalId] ?? originalId
                        speakerEmbeddings[remappedId] = embedding
                    }
                }

                let uniqueRemappedSpeakers = Set(remappedSegments.map(\.speakerId))
                Logger.app.info("MeetingFinalProcessor: diarization produced \(remoteSegments.count) remote segments, \(uniqueRemappedSpeakers.count) speakers")
            } catch {
                Logger.app.error("MeetingFinalProcessor: diarization failed, falling back: \(error)")
                remoteSegments = makeFallbackRemoteSegments(sys: sys, duration: duration)
            }
        } else {
            // No diarizer — all system audio → single remote speaker
            remoteSegments = makeFallbackRemoteSegments(sys: sys, duration: duration)
        }

        // Merge local + remote, sorted by startTime, then group consecutive same-speaker
        let merged = (localSegments + remoteSegments).sorted { $0.startTime < $1.startTime }
        let grouped = groupConsecutiveSpeakers(merged)

        let uniqueSpeakers = Set(grouped.map(\.speakerId))

        return MeetingProcessingResult(
            segments: grouped,
            speakerCount: uniqueSpeakers.count,
            speakerEmbeddings: speakerEmbeddings
        )
    }

    // MARK: - Private Helpers

    private func groupTokens(_ timings: [TokenTiming], speakerId: String, startOffset: Double) -> [AttributedSegment] {
        var result: [AttributedSegment] = []
        var currentWords: [String] = []
        var currentStart: Double = 0
        var currentEnd: Double = 0

        for timing in timings {
            let token = timing.token.trimmingCharacters(in: .whitespaces)
            guard !token.isEmpty else { continue }

            if currentWords.isEmpty {
                currentStart = startOffset + timing.startTime
            }
            currentWords.append(timing.token)
            currentEnd = startOffset + timing.endTime

            // Break into sentences at natural pauses (>1s gap)
            if let nextIndex = timings.firstIndex(where: { $0.startTime > timing.endTime }),
               timings[nextIndex].startTime - timing.endTime > 1.0 {
                let text = currentWords.joined(separator: "").trimmingCharacters(in: .whitespaces)
                if !text.isEmpty {
                    result.append(AttributedSegment(
                        speakerId: speakerId,
                        text: text,
                        startTime: currentStart,
                        endTime: currentEnd
                    ))
                }
                currentWords = []
            }
        }

        if !currentWords.isEmpty {
            let text = currentWords.joined(separator: "").trimmingCharacters(in: .whitespaces)
            if !text.isEmpty {
                result.append(AttributedSegment(
                    speakerId: speakerId,
                    text: text,
                    startTime: currentStart,
                    endTime: currentEnd
                ))
            }
        }

        return result
    }

    /// Remap diarizer speaker IDs to "remote-N" format.
    /// Returns new TimedSpeakerSegments with remapped speakerIds.
    private func remapSpeakerIds(_ segments: [TimedSpeakerSegment]) -> [TimedSpeakerSegment] {
        let idMap = buildSpeakerIdMap(segments)
        return segments.map { seg in
            TimedSpeakerSegment(
                speakerId: idMap[seg.speakerId] ?? seg.speakerId,
                embedding: seg.embedding,
                startTimeSeconds: seg.startTimeSeconds,
                endTimeSeconds: seg.endTimeSeconds,
                qualityScore: seg.qualityScore
            )
        }
    }

    /// Build a mapping from original diarizer IDs to "remote-N" IDs.
    private func buildSpeakerIdMap(_ segments: [TimedSpeakerSegment]) -> [String: String] {
        var seen: [String] = []
        for seg in segments {
            if !seen.contains(seg.speakerId) {
                seen.append(seg.speakerId)
            }
        }
        var map: [String: String] = [:]
        for (index, id) in seen.enumerated() {
            map[id] = "remote-\(index + 1)"
        }
        return map
    }

    private func makeFallbackRemoteSegments(sys: ASRResult, duration: TimeInterval) -> [AttributedSegment] {
        if let timings = sys.tokenTimings, !timings.isEmpty {
            return groupTokens(timings, speakerId: "remote-1", startOffset: 0)
        }
        let text = sys.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        return [AttributedSegment(
            speakerId: "remote-1",
            text: text,
            startTime: 0,
            endTime: duration
        )]
    }

    /// Check if the WAV file at `url` contains non-silent audio.
    /// Returns false if the file is all zeros or RMS is below threshold.
    private func hasAudioContent(_ url: URL, threshold: Float = 0.001) -> Bool {
        guard let audioFile = try? AVAudioFile(forReading: url) else {
            Logger.app.warning("MeetingFinalProcessor: could not open audio file for content check: \(url.lastPathComponent)")
            return false
        }
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: min(frameCount, 160_000)),
              let _ = try? audioFile.read(into: buffer),
              let channelData = buffer.floatChannelData else {
            return false
        }
        var rms: Float = 0
        vDSP_rmsqv(channelData[0], 1, &rms, vDSP_Length(buffer.frameLength))
        Logger.app.info("MeetingFinalProcessor: system audio RMS = \(rms)")
        return rms > threshold
    }

    /// Group consecutive segments with the same speaker into single segments.
    private func groupConsecutiveSpeakers(_ segments: [AttributedSegment]) -> [AttributedSegment] {
        guard !segments.isEmpty else { return [] }

        var result: [AttributedSegment] = []
        var current = segments[0]

        for seg in segments.dropFirst() {
            if seg.speakerId == current.speakerId {
                // Merge
                current = AttributedSegment(
                    speakerId: current.speakerId,
                    text: current.text + " " + seg.text,
                    startTime: current.startTime,
                    endTime: seg.endTime
                )
            } else {
                result.append(current)
                current = seg
            }
        }
        result.append(current)

        return result.filter { !$0.text.isEmpty }
    }
}
