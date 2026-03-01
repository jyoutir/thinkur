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
        // Phrase-level assignment: entire phrase overlaps mostly with A → all words A
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
        // All words should be assigned to speaker A (phrase majority overlap)
        let allText = result.map(\.text).joined(separator: " ")
        #expect(allText.contains("be"))
        #expect(allText.contains("perfect"))
        for seg in result {
            #expect(seg.speakerId == "A")
        }
    }

    // MARK: - Phrase-level assignment tests

    @Test("Mid-sentence word not clipped to next speaker")
    func midSentenceWordNotClipped() {
        // "these will be perfect for you" — diarizer boundary falls mid-phrase
        // Speaker B starts at 1.5s, but "for" at 1.4-1.6 and "you" at 1.6-1.8
        // straddle the boundary. Phrase-level: whole phrase overlap is majority A.
        let tokens = [
            token(" these", start: 0.0, end: 0.3),
            token(" will", start: 0.3, end: 0.6),
            token(" be", start: 0.6, end: 0.8),
            token(" per", start: 0.8, end: 1.0),
            token("fect", start: 1.0, end: 1.2),
            token(" for", start: 1.2, end: 1.4),
            token(" you", start: 1.4, end: 1.6),
        ]
        let segments = [
            segment("A", start: 0.0, end: 1.5),
            segment("B", start: 1.5, end: 3.0),
        ]
        let result = MeetingTranscriptionMerger.mergeTimingsWithSpeakers(
            tokenTimings: tokens, speakerSegments: segments, chunkStartTime: 0
        )
        // Entire phrase "these will be perfect for you" → Speaker A (majority overlap)
        let allText = result.map(\.text).joined(separator: " ")
        #expect(allText.contains("perfect for you"))
        for seg in result {
            #expect(seg.speakerId == "A")
        }
    }

    @Test("Phantom speaker absorbed by phrase majority")
    func phantomSpeakerAbsorbed() {
        // Diarizer produces a 3-word Speaker C segment inside a B phrase.
        // Phrase-level: the full phrase overlaps mostly with B → all words B.
        let tokens = [
            token(" I", start: 5.0, end: 5.1),
            token(" think", start: 5.1, end: 5.3),
            token(" we", start: 5.3, end: 5.5),
            token(" should", start: 5.5, end: 5.7),
            token(" try", start: 5.7, end: 5.9),
            token(" that", start: 5.9, end: 6.1),
        ]
        let segments = [
            segment("B", start: 5.0, end: 5.4),
            segment("C", start: 5.4, end: 5.7),   // phantom — 0.3s blip
            segment("B", start: 5.7, end: 6.5),
        ]
        let result = MeetingTranscriptionMerger.mergeTimingsWithSpeakers(
            tokenTimings: tokens, speakerSegments: segments, chunkStartTime: 0
        )
        // All words in single phrase → Speaker B (majority overlap: 0.4 + 0.4 = 0.8 vs C's 0.3)
        let allText = result.map(\.text).joined(separator: " ")
        #expect(allText == "I think we should try that")
        for seg in result {
            #expect(seg.speakerId == "B")
        }
    }

    @Test("Phrase splits at punctuation preserve speaker transition")
    func phraseSplitAtPunctuationPreservesSpeaker() {
        // "Hello." (A) + "How are you?" (B) — punctuation creates phrase boundary
        let tokens = [
            token(" Hello.", start: 0.0, end: 0.5),
            token(" How", start: 0.6, end: 0.8),
            token(" are", start: 0.8, end: 0.9),
            token(" you?", start: 0.9, end: 1.1),
        ]
        let segments = [
            segment("A", start: 0.0, end: 0.55),
            segment("B", start: 0.55, end: 2.0),
        ]
        let result = MeetingTranscriptionMerger.mergeTimingsWithSpeakers(
            tokenTimings: tokens, speakerSegments: segments, chunkStartTime: 0
        )
        // Period splits into two phrases, each assigned independently
        #expect(result.count == 2)
        #expect(result[0].text == "Hello.")
        #expect(result[0].speakerId == "A")
        #expect(result[1].text == "How are you?")
        #expect(result[1].speakerId == "B")
    }

    @Test("Phrase splits at timing gap preserve speaker transition")
    func phraseSplitAtTimingGapPreservesSpeaker() {
        // 0.7s gap between speakers (no punctuation) → phrase split at gap
        let tokens = [
            token(" Hey", start: 0.0, end: 0.3),
            token(" there", start: 0.3, end: 0.6),
            // 0.7s gap — above 0.5s threshold
            token(" What's", start: 1.3, end: 1.5),
            token(" up", start: 1.5, end: 1.7),
        ]
        let segments = [
            segment("A", start: 0.0, end: 1.0),
            segment("B", start: 1.0, end: 2.0),
        ]
        let result = MeetingTranscriptionMerger.mergeTimingsWithSpeakers(
            tokenTimings: tokens, speakerSegments: segments, chunkStartTime: 0
        )
        // Gap creates two phrases, each assigned to correct speaker
        #expect(result.count == 2)
        #expect(result[0].text == "Hey there")
        #expect(result[0].speakerId == "A")
        #expect(result[1].text == "What's up")
        #expect(result[1].speakerId == "B")
    }
}
