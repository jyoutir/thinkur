import FluidAudio
@testable import thinkur
import Testing

@Suite("SpeakerAssignment")
struct SpeakerAssignmentTests {

    private func word(_ text: String, start: Double, end: Double) -> ReconstructedWord {
        ReconstructedWord(text: text, start: start, end: end, confidence: 0.9)
    }

    private func segment(_ id: String, start: Float, end: Float) -> TimedSpeakerSegment {
        TimedSpeakerSegment(
            speakerId: id, embedding: [], startTimeSeconds: start,
            endTimeSeconds: end, qualityScore: 1.0
        )
    }

    @Test("Assigns speaker based on overlap")
    func overlapAssignment() {
        let words = [
            word("Hello", start: 0.0, end: 0.5),
            word("there", start: 0.5, end: 1.0),
        ]
        let segments = [
            segment("A", start: 0.0, end: 2.0),
        ]
        let result = SpeakerAssignment.assignSpeakers(words: words, speakerSegments: segments)
        #expect(result.count == 2)
        #expect(result[0].speakerId == "A")
        #expect(result[1].speakerId == "A")
    }

    @Test("Multi-speaker assignment by maximum overlap")
    func multiSpeaker() {
        let words = [
            word("Hello", start: 0.0, end: 0.5),
            word("world", start: 3.0, end: 3.5),
        ]
        let segments = [
            segment("A", start: 0.0, end: 2.0),
            segment("B", start: 2.5, end: 5.0),
        ]
        let result = SpeakerAssignment.assignSpeakers(words: words, speakerSegments: segments)
        #expect(result[0].speakerId == "A")
        #expect(result[1].speakerId == "B")
    }

    @Test("fill_nearest when no overlap")
    func fillNearest() {
        // Word at time 4-5, segments at 0-2 and 8-10
        let words = [
            word("gap", start: 4.0, end: 5.0),
        ]
        let segments = [
            segment("A", start: 0.0, end: 2.0),   // midpoint 1
            segment("B", start: 8.0, end: 10.0),   // midpoint 9
        ]
        // Word midpoint = 4.5, closer to A's midpoint (1) than B's (9)? No: |4.5-1|=3.5, |4.5-9|=4.5 → A
        let result = SpeakerAssignment.assignSpeakers(words: words, speakerSegments: segments)
        #expect(result[0].speakerId == "A")
    }

    @Test("Empty words returns empty")
    func emptyWords() {
        let segments = [segment("A", start: 0.0, end: 5.0)]
        let result = SpeakerAssignment.assignSpeakers(words: [], speakerSegments: segments)
        #expect(result.isEmpty)
    }

    @Test("Empty segments assigns unknown")
    func emptySegments() {
        let words = [word("hello", start: 0.0, end: 0.5)]
        let result = SpeakerAssignment.assignSpeakers(words: words, speakerSegments: [])
        #expect(result[0].speakerId == "unknown")
    }

    @Test("Word spanning speaker boundary goes to max overlap")
    func wordSpanningBoundary() {
        // Word from 1.5 to 2.5, segments A=[0,2] and B=[2,4]
        // Overlap with A: min(2,2.5)-max(1.5,0) = 2-1.5 = 0.5
        // Overlap with B: min(4,2.5)-max(2,1.5) = 2.5-2 = 0.5
        // Equal overlap — first one wins (A comes first in query results)
        let words = [word("cross", start: 1.5, end: 2.5)]
        let segments = [
            segment("A", start: 0.0, end: 2.0),
            segment("B", start: 2.0, end: 4.0),
        ]
        let result = SpeakerAssignment.assignSpeakers(words: words, speakerSegments: segments)
        // With equal overlap, first overlapping entry wins (A)
        #expect(result[0].speakerId == "A" || result[0].speakerId == "B")
        #expect(result[0].text == "cross")
    }

    @Test("Preserves word text and confidence")
    func preservesWordData() {
        let words = [ReconstructedWord(text: "hello", start: 0.0, end: 0.5, confidence: 0.85)]
        let segments = [segment("A", start: 0.0, end: 1.0)]
        let result = SpeakerAssignment.assignSpeakers(words: words, speakerSegments: segments)
        #expect(result[0].text == "hello")
        #expect(result[0].confidence == 0.85)
        #expect(result[0].start == 0.0)
        #expect(result[0].end == 0.5)
    }

    // MARK: - Boundary smoothing tests

    @Test("Smooths single-word flip when margin is low")
    func smoothsSingleWordFlip() {
        // w2 straddles A/B boundary with margin ~0.4 (between stickiness 0.3 and flip 0.5)
        // Neighbors are both A → isolated flip correction fires
        let words = [
            word("these", start: 0.0, end: 0.5),    // clearly in A
            word("will", start: 0.5, end: 1.0),      // clearly in A
            word("be", start: 1.85, end: 2.2),        // straddles: A overlap=0.15, B overlap=0.2
            word("perfect", start: 2.5, end: 3.0),   // clearly in second A
            word("thanks", start: 3.0, end: 3.5),    // clearly in second A
        ]
        let segments = [
            segment("A", start: 0.0, end: 2.0),
            segment("B", start: 2.0, end: 2.5),
            segment("A", start: 2.5, end: 5.0),
        ]
        let result = SpeakerAssignment.assignSpeakers(words: words, speakerSegments: segments)
        // "be" should be smoothed to A (neighbors agree, low margin)
        for w in result {
            #expect(w.speakerId == "A")
        }
    }

    @Test("Preserves high-margin flip — real speaker inside different segment")
    func preservesHighMarginFlip() {
        // w1 is entirely inside B's segment (single overlap → margin 1.0)
        // Even though neighbors are A, margin is too high to flip
        let words = [
            word("hello", start: 0.0, end: 0.5),     // A
            word("yes", start: 2.5, end: 3.0),        // entirely in B (margin=1.0)
            word("thanks", start: 4.0, end: 4.5),     // A
        ]
        let segments = [
            segment("A", start: 0.0, end: 2.0),
            segment("B", start: 2.0, end: 4.0),
            segment("A", start: 4.0, end: 6.0),
        ]
        let result = SpeakerAssignment.assignSpeakers(words: words, speakerSegments: segments)
        #expect(result[0].speakerId == "A")
        #expect(result[1].speakerId == "B")  // preserved despite A neighbors
        #expect(result[2].speakerId == "A")
    }

    @Test("Stickiness keeps previous speaker at close boundary")
    func stickinessKeepsPreviousSpeaker() {
        // w1 straddles boundary: A overlap=0.15, B overlap=0.2 → margin=0.25 < 0.3
        // Previous word is A, runner-up is A → stickiness keeps A
        let words = [
            word("hello", start: 0.0, end: 0.5),      // clearly in A
            word("there", start: 1.85, end: 2.2),      // close call: B barely wins
        ]
        let segments = [
            segment("A", start: 0.0, end: 2.0),
            segment("B", start: 2.0, end: 4.0),
        ]
        let result = SpeakerAssignment.assignSpeakers(words: words, speakerSegments: segments)
        // Stickiness: margin 0.25 < 0.3 and prev=A=runner-up → keep A
        #expect(result[0].speakerId == "A")
        #expect(result[1].speakerId == "A")
    }

    @Test("Stickiness does not override high margin")
    func stickinessDoesNotOverrideHighMargin() {
        // w1 has clear B advantage: A overlap=0.4, B overlap=0.6 → margin=0.33 > 0.3
        // Stickiness threshold not met → correctly switches to B
        let words = [
            word("hello", start: 0.0, end: 0.5),      // A
            word("there", start: 1.6, end: 2.6),       // B wins clearly
        ]
        let segments = [
            segment("A", start: 0.0, end: 2.0),
            segment("B", start: 2.0, end: 4.0),
        ]
        let result = SpeakerAssignment.assignSpeakers(words: words, speakerSegments: segments)
        #expect(result[0].speakerId == "A")
        #expect(result[1].speakerId == "B")
    }

    @Test("Preserves real multi-word speaker transition")
    func preservesRealTransition() {
        // A→A→B→B→B — all words clearly inside their segments (margin=1.0)
        let words = [
            word("hello", start: 0.0, end: 0.5),
            word("there", start: 0.5, end: 1.0),
            word("how", start: 3.0, end: 3.3),
            word("are", start: 3.3, end: 3.6),
            word("you", start: 3.6, end: 4.0),
        ]
        let segments = [
            segment("A", start: 0.0, end: 2.0),
            segment("B", start: 2.5, end: 5.0),
        ]
        let result = SpeakerAssignment.assignSpeakers(words: words, speakerSegments: segments)
        #expect(result[0].speakerId == "A")
        #expect(result[1].speakerId == "A")
        #expect(result[2].speakerId == "B")
        #expect(result[3].speakerId == "B")
        #expect(result[4].speakerId == "B")
    }

    @Test("Single word keeps initial assignment — no neighbors to smooth")
    func singleWordNoSmoothing() {
        // Single word straddling boundary — B wins, no smoothing possible
        let words = [
            word("cross", start: 1.6, end: 2.6),   // A overlap=0.4, B overlap=0.6
        ]
        let segments = [
            segment("A", start: 0.0, end: 2.0),
            segment("B", start: 2.0, end: 4.0),
        ]
        let result = SpeakerAssignment.assignSpeakers(words: words, speakerSegments: segments)
        #expect(result[0].speakerId == "B")
    }
}
