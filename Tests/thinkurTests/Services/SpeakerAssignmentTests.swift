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
}
