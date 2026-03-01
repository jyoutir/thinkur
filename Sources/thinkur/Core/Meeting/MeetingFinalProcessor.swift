/// Final-only meeting processing pipeline.
///
/// After recording stops, both WAV tracks (mic + system) are transcribed in parallel via AsrManager.
/// The system track is run through speaker diarization (FluidAudio CoreML/ANE) to identify distinct
/// remote speakers. ASR token timings are merged with diarization speaker segments to produce
/// speaker-attributed text. Phantom speakers (< 15% speaking time) are merged into their nearest
/// temporal neighbor. Mic audio is VAD-gated to suppress phantom "You" segments from echo/ambient
/// pickup.

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
    private let vadManager: VadManager?

    init(
        asrManager: AsrManager,
        offlineDiarizer: OfflineDiarizerManager?,
        vadManager: VadManager?
    ) {
        self.asrManager = asrManager
        self.offlineDiarizer = offlineDiarizer
        self.vadManager = vadManager
    }

    func process(micURL: URL, systemURL: URL, duration: TimeInterval) async throws -> MeetingProcessingResult {
        // Transcribe both tracks in parallel
        // AsrManager has separate decoder states for .microphone and .system sources
        async let micResult = asrManager.transcribe(micURL, source: .microphone)
        async let sysResult = asrManager.transcribe(systemURL, source: .system)

        let (mic, sys) = try await (micResult, sysResult)

        Logger.app.info("MeetingFinalProcessor: mic=\(mic.text.count) chars, sys=\(sys.text.count) chars")

        // Echo detection: if mic picked up system audio (speaker playback), suppress local segments
        let isEcho = detectEcho(micText: mic.text, sysText: sys.text)
        if isEcho {
            Logger.app.info("MeetingFinalProcessor: echo detected — suppressing local (You) segments")
        }

        // VAD mic gating: suppress phantom "You" from echo/ambient pickup
        let vadSuppressed = await shouldSuppressMic(micURL: micURL, duration: duration)

        // Build local speaker segments from mic tokens (skip if echo detected or VAD suppressed)
        var localSegments: [AttributedSegment] = []
        if !isEcho && !vadSuppressed {
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
        } else {
            // Run FluidAudio CoreML/ANE diarizer on system audio
            let diarizationResult = await runDiarization(systemURL: systemURL)

            if let result = diarizationResult {
                let uniqueRawSpeakers = Set(result.segments.map(\.speakerId))
                Logger.app.info("MeetingFinalProcessor: diarizer returned \(result.segments.count) segments, \(uniqueRawSpeakers.count) unique speakers: \(uniqueRawSpeakers)")

                // Remap diarizer speaker IDs → "remote-1", "remote-2", ...
                var remappedSegments = remapSpeakerIds(result.segments)

                // Phantom speaker merge: absorb speakers with < 15% speaking time
                remappedSegments = mergePhantomSpeakers(remappedSegments, threshold: 0.15)

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
                if let db = result.speakerDatabase {
                    let speakerIdMap = buildSpeakerIdMap(result.segments)
                    for (originalId, embedding) in db {
                        let remappedId = speakerIdMap[originalId] ?? originalId
                        speakerEmbeddings[remappedId] = embedding
                    }
                }

                let uniqueRemappedSpeakers = Set(remappedSegments.map(\.speakerId))
                Logger.app.info("MeetingFinalProcessor: diarization produced \(remoteSegments.count) remote segments, \(uniqueRemappedSpeakers.count) speakers")
            } else {
                // Diarization failed — all system audio → single remote speaker
                remoteSegments = makeFallbackRemoteSegments(sys: sys, duration: duration)
            }
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

    // MARK: - Diarization

    /// Run diarization using FluidAudio (CoreML/ANE).
    private func runDiarization(systemURL: URL) async -> DiarizationResult? {
        guard let diarizer = offlineDiarizer else { return nil }

        do {
            let result = try await diarizer.process(systemURL)
            Logger.app.info("MeetingFinalProcessor: diarization succeeded (\(result.segments.count) segments)")
            return result
        } catch {
            Logger.app.error("MeetingFinalProcessor: diarization failed: \(error)")
            return nil
        }
    }

    // MARK: - Phantom Speaker Merge

    /// Merge speakers with less than `threshold` (fraction) of total speaking time
    /// into their nearest temporal neighbor. Absorbs phantom Speaker 3 from diarizer noise.
    private func mergePhantomSpeakers(_ segments: [TimedSpeakerSegment], threshold: Float) -> [TimedSpeakerSegment] {
        guard !segments.isEmpty else { return segments }

        // Calculate total speaking time per speaker
        var speakerDuration: [String: Float] = [:]
        for seg in segments {
            speakerDuration[seg.speakerId, default: 0] += seg.durationSeconds
        }

        let totalDuration = speakerDuration.values.reduce(0, +)
        guard totalDuration > 0 else { return segments }

        // Find phantom speakers (< threshold fraction of total)
        let phantomSpeakers = speakerDuration.filter { $0.value / totalDuration < threshold }
        guard !phantomSpeakers.isEmpty else { return segments }

        // Find non-phantom speakers
        let realSpeakers = Set(speakerDuration.keys).subtracting(phantomSpeakers.keys)
        guard !realSpeakers.isEmpty else { return segments }

        Logger.app.info("MeetingFinalProcessor: merging phantom speakers \(Array(phantomSpeakers.keys)) into nearest neighbor")

        // For each phantom segment, find the nearest real-speaker segment in time
        return segments.map { seg in
            guard phantomSpeakers.keys.contains(seg.speakerId) else { return seg }

            let segMid = (seg.startTimeSeconds + seg.endTimeSeconds) / 2.0
            let nearest = segments
                .filter { realSpeakers.contains($0.speakerId) }
                .min(by: {
                    let mid0 = ($0.startTimeSeconds + $0.endTimeSeconds) / 2.0
                    let mid1 = ($1.startTimeSeconds + $1.endTimeSeconds) / 2.0
                    return abs(mid0 - segMid) < abs(mid1 - segMid)
                })

            guard let nearest else { return seg }

            return TimedSpeakerSegment(
                speakerId: nearest.speakerId,
                embedding: seg.embedding,
                startTimeSeconds: seg.startTimeSeconds,
                endTimeSeconds: seg.endTimeSeconds,
                qualityScore: seg.qualityScore
            )
        }
    }

    // MARK: - VAD Mic Gating

    /// Use VAD to check if mic audio contains meaningful speech.
    /// Returns true (suppress) if VAD speech < 1.0s for meetings > 30s.
    private func shouldSuppressMic(micURL: URL, duration: TimeInterval) async -> Bool {
        guard duration > 30.0, let vad = vadManager else { return false }

        do {
            let vadResults = try await vad.process(micURL)
            // Each VAD chunk is 4096 samples at 16kHz = 0.256s
            let chunkDuration = Double(VadManager.chunkSize) / Double(VadManager.sampleRate)
            let totalSpeech = vadResults.filter(\.isVoiceActive).count
            let speechDuration = Double(totalSpeech) * chunkDuration
            Logger.app.info("MeetingFinalProcessor: VAD detected \(String(format: "%.1f", speechDuration))s speech in mic audio")

            if speechDuration < 1.0 {
                Logger.app.info("MeetingFinalProcessor: VAD gating — suppressing mic (< 1.0s speech in \(String(format: "%.0f", duration))s meeting)")
                return true
            }
        } catch {
            Logger.app.warning("MeetingFinalProcessor: VAD check failed, allowing mic audio: \(error)")
        }

        return false
    }

    // MARK: - Echo Detection

    /// Detect if the mic audio is an echo of system audio (speaker playback picked up by mic).
    /// Uses Jaccard word similarity: if > 50% of words overlap, it's likely echo.
    private func detectEcho(micText: String, sysText: String) -> Bool {
        let micNorm = normalizeForComparison(micText)
        let sysNorm = normalizeForComparison(sysText)

        guard !micNorm.isEmpty, !sysNorm.isEmpty else { return false }

        let micWords = Set(micNorm.split(separator: " ").map(String.init))
        let sysWords = Set(sysNorm.split(separator: " ").map(String.init))

        let intersection = micWords.intersection(sysWords).count
        let union = micWords.union(sysWords).count

        guard union > 0 else { return false }

        let similarity = Double(intersection) / Double(union)
        Logger.app.info("MeetingFinalProcessor: echo check — Jaccard similarity = \(String(format: "%.2f", similarity))")
        return similarity > 0.5
    }

    /// Normalize text for echo comparison: lowercase, strip punctuation, collapse whitespace.
    private func normalizeForComparison(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
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
