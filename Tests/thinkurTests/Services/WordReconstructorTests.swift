import FluidAudio
@testable import thinkur
import Testing

@Suite("WordReconstructor")
struct WordReconstructorTests {

    private func token(_ text: String, start: Double, end: Double, confidence: Float = 0.9) -> TokenTiming {
        TokenTiming(token: text, tokenId: 0, startTime: start, endTime: end, confidence: confidence)
    }

    @Test("Groups sub-word tokens into whole words")
    func subwordGrouping() {
        // "per" + "fect" -> "perfect"
        let tokens = [
            token(" per", start: 0.0, end: 0.2),
            token("fect", start: 0.2, end: 0.4),
        ]
        let words = WordReconstructor.reconstruct(tokens: tokens)
        #expect(words.count == 1)
        #expect(words[0].text == "perfect")
        #expect(words[0].start == 0.0)
        #expect(words[0].end == 0.4)
    }

    @Test("Leading space starts new word")
    func leadingSpaceConvention() {
        let tokens = [
            token(" Hello", start: 0.0, end: 0.3),
            token(" world", start: 0.3, end: 0.6),
        ]
        let words = WordReconstructor.reconstruct(tokens: tokens)
        #expect(words.count == 2)
        #expect(words[0].text == "Hello")
        #expect(words[1].text == "world")
    }

    @Test("First token without leading space treated as word start")
    func firstTokenNoSpace() {
        let tokens = [
            token("The", start: 0.0, end: 0.1),
            token(" quick", start: 0.1, end: 0.3),
        ]
        let words = WordReconstructor.reconstruct(tokens: tokens)
        #expect(words.count == 2)
        #expect(words[0].text == "The")
        #expect(words[1].text == "quick")
    }

    @Test("Single-token words preserved")
    func singleTokenWords() {
        let tokens = [
            token(" I", start: 0.0, end: 0.1),
            token(" am", start: 0.1, end: 0.2),
            token(" fine", start: 0.2, end: 0.4),
        ]
        let words = WordReconstructor.reconstruct(tokens: tokens)
        #expect(words.count == 3)
        #expect(words.map(\.text) == ["I", "am", "fine"])
    }

    @Test("Confidence is averaged across constituent tokens")
    func confidenceAveraging() {
        let tokens = [
            token(" per", start: 0.0, end: 0.2, confidence: 0.8),
            token("fect", start: 0.2, end: 0.4, confidence: 0.6),
        ]
        let words = WordReconstructor.reconstruct(tokens: tokens)
        #expect(words.count == 1)
        #expect(words[0].confidence == 0.7) // (0.8 + 0.6) / 2
    }

    @Test("chunkStartTime offsets word timings")
    func chunkOffset() {
        let tokens = [
            token(" Hello", start: 0.0, end: 0.3),
        ]
        let words = WordReconstructor.reconstruct(tokens: tokens, chunkStartTime: 10.0)
        #expect(words[0].start == 10.0)
        #expect(words[0].end == 10.3)
    }

    @Test("Empty tokens list returns empty")
    func emptyTokens() {
        let words = WordReconstructor.reconstruct(tokens: [])
        #expect(words.isEmpty)
    }

    @Test("Multi-part BPE reconstruction: I've")
    func multiPartBPE() {
        let tokens = [
            token(" I", start: 0.0, end: 0.1),
            token("'ve", start: 0.1, end: 0.2),
        ]
        let words = WordReconstructor.reconstruct(tokens: tokens)
        #expect(words.count == 1)
        #expect(words[0].text == "I've")
    }

    @Test("Handles mixed single and multi-part tokens")
    func mixedTokens() {
        // "It's been a while since"
        let tokens = [
            token(" It", start: 0.0, end: 0.1),
            token("'s", start: 0.1, end: 0.15),
            token(" been", start: 0.15, end: 0.3),
            token(" a", start: 0.3, end: 0.35),
            token(" wh", start: 0.35, end: 0.4),
            token("ile", start: 0.4, end: 0.5),
            token(" since", start: 0.5, end: 0.7),
        ]
        let words = WordReconstructor.reconstruct(tokens: tokens)
        #expect(words.map(\.text) == ["It's", "been", "a", "while", "since"])
    }
}
