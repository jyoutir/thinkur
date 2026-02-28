import FluidAudio
@testable import thinkur
import Testing

@Suite("MeetingTranscriptionMerger")
struct MeetingTranscriptionMergerTests {

    private func token(_ text: String, start: Double, end: Double, confidence: Float = 0.9) -> TokenTiming {
        TokenTiming(token: text, tokenId: 0, startTime: start, endTime: end, confidence: confidence)
    }

    private func segment(_ id: String, start: Float, end: Float) -> TimedSpeakerSegment {
        TimedSpeakerSegment(
            speakerId: id, embedding: [], startTimeSeconds: start,
            endTimeSeconds: end, qualityScore: 1.0
        )
    }

    @Test("Full pipeline: BPE tokens reconstructed and assigned to correct speakers")
    func fullPipeline() {
        // Speaker A says "Hello there" (0-2s), Speaker B says "How are you" (3-5s)
        let tokens = [
            token(" Hello", start: 0.0, end: 0.5),
            token(" there", start: 0.5, end: 1.0),
            token(" How", start: 3.0, end: 3.3),
            token(" are", start: 3.3, end: 3.6),
            token(" you", start: 3.6, end: 4.0),
        ]
        let segments = [
            segment("A", start: 0.0, end: 2.0),
            segment("B", start: 2.5, end: 5.0),
        ]
        let result = MeetingTranscriptionMerger.mergeTimingsWithSpeakers(
            tokenTimings: tokens, speakerSegments: segments, chunkStartTime: 0
        )
        // Should produce segments split by speaker + long pause (>1s gap between 1.0 and 3.0)
        #expect(result.count >= 2)
        #expect(result[0].speakerId == "A")
        #expect(result[0].text.contains("Hello"))
        #expect(result[1].speakerId == "B")
        #expect(result[1].text.contains("How"))
    }

    @Test("Sub-word tokens are not split across speakers")
    func noMidWordSplits() {
        // "perfect" as two BPE tokens, both within speaker A's segment
        let tokens = [
            token(" per", start: 0.0, end: 0.2),
            token("fect", start: 0.2, end: 0.4),
            token(" word", start: 0.5, end: 0.8),
        ]
        let segments = [
            segment("A", start: 0.0, end: 1.0),
        ]
        let result = MeetingTranscriptionMerger.mergeTimingsWithSpeakers(
            tokenTimings: tokens, speakerSegments: segments, chunkStartTime: 0
        )
        // "perfect" should appear as one word, not split
        let allText = result.map(\.text).joined(separator: " ")
        #expect(allText.contains("perfect"))
        #expect(!allText.contains("per "))
        #expect(!allText.contains(" fect"))
    }

    @Test("Empty tokens returns empty")
    func emptyTokens() {
        let segments = [segment("A", start: 0.0, end: 5.0)]
        let result = MeetingTranscriptionMerger.mergeTimingsWithSpeakers(
            tokenTimings: [], speakerSegments: segments, chunkStartTime: 0
        )
        #expect(result.isEmpty)
    }

    @Test("Empty segments returns empty")
    func emptySegments() {
        let tokens = [token(" Hello", start: 0.0, end: 0.5)]
        let result = MeetingTranscriptionMerger.mergeTimingsWithSpeakers(
            tokenTimings: tokens, speakerSegments: [], chunkStartTime: 0
        )
        #expect(result.isEmpty)
    }

    @Test("chunkStartTime offsets token times")
    func chunkOffset() {
        let tokens = [
            token(" Hello", start: 0.0, end: 0.5),
        ]
        let segments = [
            segment("A", start: 10.0, end: 12.0),
        ]
        let result = MeetingTranscriptionMerger.mergeTimingsWithSpeakers(
            tokenTimings: tokens, speakerSegments: segments, chunkStartTime: 10.0
        )
        #expect(result.count == 1)
        #expect(result[0].speakerId == "A")
        #expect(result[0].startTime == 10.0)
    }

    @Test("Sentence break at punctuation")
    func sentenceBreakAtPunctuation() {
        let tokens = [
            token(" Hello.", start: 0.0, end: 0.5),
            token(" How", start: 0.6, end: 0.8),
            token(" are", start: 0.8, end: 0.9),
            token(" you?", start: 0.9, end: 1.1),
        ]
        let segments = [
            segment("A", start: 0.0, end: 2.0),
        ]
        let result = MeetingTranscriptionMerger.mergeTimingsWithSpeakers(
            tokenTimings: tokens, speakerSegments: segments, chunkStartTime: 0
        )
        // Should break into two sentences at the period
        #expect(result.count == 2)
        #expect(result[0].text == "Hello.")
        #expect(result[1].text == "How are you?")
    }

    @Test("Realistic fragmented transcript produces clean output")
    func realisticFragmented() {
        // Simulates the actual fragmented output that motivated this change:
        // BPE tokens that would split words across speaker boundaries
        let tokens = [
            token(" It", start: 0.0, end: 0.1),
            token("'s", start: 0.1, end: 0.15),
            token(" been", start: 0.15, end: 0.3),
            token(" a", start: 0.3, end: 0.35),
            token(" wh", start: 0.35, end: 0.4),
            token("ile.", start: 0.4, end: 0.5),
            token(" I", start: 2.0, end: 2.1),
            token("'ve", start: 2.1, end: 2.2),
            token(" been", start: 2.2, end: 2.4),
            token(" busy.", start: 2.4, end: 2.6),
        ]
        let segments = [
            segment("remote-1", start: 0.0, end: 1.0),
            segment("remote-2", start: 1.5, end: 3.0),
        ]
        let result = MeetingTranscriptionMerger.mergeTimingsWithSpeakers(
            tokenTimings: tokens, speakerSegments: segments, chunkStartTime: 0
        )
        // Words should be reconstructed properly, no mid-word splits
        let allText = result.map(\.text).joined(separator: " ")
        #expect(allText.contains("It's"))
        #expect(allText.contains("while."))
        #expect(allText.contains("I've"))
        #expect(allText.contains("busy."))
        // Each segment should have a valid speaker
        for seg in result {
            #expect(seg.speakerId == "remote-1" || seg.speakerId == "remote-2")
        }
    }

    @Test("Boundary smoothing keeps straddling word with correct speaker")
    func boundarySmoothing() {
        // "these will be perfect" — "be" straddles a brief mis-classified B segment
        // Diarizer placed B at [0.66, 0.74] (80ms error), A everywhere else
        // Without smoothing, "be" would get assigned to B, fragmenting the sentence
        let tokens = [
            token(" these", start: 0.0, end: 0.3),
            token(" will", start: 0.3, end: 0.6),
            token(" be", start: 0.6, end: 0.8),
            token(" per", start: 0.8, end: 1.0),
            token("fect", start: 1.0, end: 1.2),
        ]
        let segments = [
            segment("A", start: 0.0, end: 0.66),
            segment("B", start: 0.66, end: 0.74),
            segment("A", start: 0.74, end: 2.0),
        ]
        let result = MeetingTranscriptionMerger.mergeTimingsWithSpeakers(
            tokenTimings: tokens, speakerSegments: segments, chunkStartTime: 0
        )
        // All words should be assigned to speaker A after smoothing
        let allText = result.map(\.text).joined(separator: " ")
        #expect(allText.contains("be"))
        #expect(allText.contains("perfect"))
        for seg in result {
            #expect(seg.speakerId == "A")
        }
    }
}
