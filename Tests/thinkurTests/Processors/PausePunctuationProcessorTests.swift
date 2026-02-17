import Testing
@testable import thinkur

@Suite("PausePunctuationProcessor")
struct PausePunctuationProcessorTests {
    let processor = PausePunctuationProcessor()

    private func makeContext(timings: [WordTimingInfo]) -> ProcessingContext {
        ProcessingContext(
            frontmostAppBundleID: "com.test",
            frontmostAppName: "Test",
            wordTimings: timings,
            appStyle: .standard
        )
    }

    // MARK: - Existing Tests

    @Test func longPauseInsertsPeriod() {
        let timings = [
            WordTimingInfo(word: "hello", start: 0.0, end: 0.5),
            WordTimingInfo(word: "world", start: 1.5, end: 2.0),
        ]
        let result = processor.process("hello world", context: makeContext(timings: timings)).text
        #expect(result.contains("."))
    }

    @Test func shortPauseInsertsComma() {
        let timings = [
            WordTimingInfo(word: "hello", start: 0.0, end: 0.5),
            WordTimingInfo(word: "world", start: 1.0, end: 1.5),
        ]
        let result = processor.process("hello world", context: makeContext(timings: timings)).text
        #expect(result.contains(","))
    }

    @Test func noPauseNoPunctuation() {
        let timings = [
            WordTimingInfo(word: "hello", start: 0.0, end: 0.3),
            WordTimingInfo(word: "world", start: 0.35, end: 0.65),
        ]
        let result = processor.process("hello world", context: makeContext(timings: timings)).text
        #expect(!result.contains(".") && !result.contains(","))
    }

    @Test func emptyTimingsReturnsOriginal() {
        let result = processor.process("hello world", context: makeContext(timings: [])).text
        #expect(result == "hello world")
    }

    @Test func singleWordReturnsOriginal() {
        let timings = [WordTimingInfo(word: "hello", start: 0.0, end: 0.5)]
        let result = processor.process("hello", context: makeContext(timings: timings)).text
        #expect(result == "hello")
    }

    @Test func questionWordAfterPause() {
        let timings = [
            WordTimingInfo(word: "ok", start: 0.0, end: 0.3),
            WordTimingInfo(word: "what", start: 1.5, end: 1.8),
            WordTimingInfo(word: "happened", start: 1.9, end: 2.3),
        ]
        let result = processor.process("ok what happened", context: makeContext(timings: timings)).text
        // "what" is a question starter, so the clause should end with "?"
        #expect(result.contains("?"))
    }

    @Test func existingPunctuationNotDuplicated() {
        let timings = [
            WordTimingInfo(word: "hello.", start: 0.0, end: 0.5),
            WordTimingInfo(word: "world", start: 1.5, end: 2.0),
        ]
        let result = processor.process("hello. world", context: makeContext(timings: timings)).text
        // Should not add double punctuation
        #expect(!result.contains(".."))
    }

    // MARK: - New Tests

    @Test func continuationWordDowngradesComma() {
        // Long pause before "and" should downgrade period to comma (not period).
        // Using only 2 timings → fewer than 5 so default thresholds apply:
        // sentenceBreak=0.8, clauseBreak=0.4. Gap of 1.0 >= 0.8 → sentence break.
        // But "and" is a continuation word so period is downgraded.
        // "done" is not in noCommaAfter, so comma is inserted.
        let timings = [
            WordTimingInfo(word: "done", start: 0.0, end: 0.5),
            WordTimingInfo(word: "and", start: 1.5, end: 1.8),
            WordTimingInfo(word: "finished", start: 1.9, end: 2.3),
        ]
        let result = processor.process("done and finished", context: makeContext(timings: timings)).text
        #expect(result.contains(","))
        // The long pause should NOT produce a period since "and" is a continuation word
        #expect(!result.contains("."))
    }

    @Test func incompleteEnderSkipsPeriod() {
        // Long pause after "the" should not insert period because "the" is
        // an incomplete ender.
        let timings = [
            WordTimingInfo(word: "the", start: 0.0, end: 0.3),
            WordTimingInfo(word: "dog", start: 1.5, end: 1.8),
        ]
        let result = processor.process("the dog", context: makeContext(timings: timings)).text
        #expect(!result.contains("."))
    }

    @Test func noCommaAfterDeterminer() {
        // Medium pause after "the" should not insert comma because "the" is
        // in noCommaAfter. Using default thresholds (clauseBreak=0.4).
        let timings = [
            WordTimingInfo(word: "the", start: 0.0, end: 0.3),
            WordTimingInfo(word: "cat", start: 0.8, end: 1.1),
        ]
        let result = processor.process("the cat", context: makeContext(timings: timings)).text
        #expect(!result.contains(","))
    }

    @Test func correctionMetadata() {
        // When punctuation is inserted, corrections should be non-empty
        let timings = [
            WordTimingInfo(word: "hello", start: 0.0, end: 0.5),
            WordTimingInfo(word: "world", start: 1.5, end: 2.0),
        ]
        let result = processor.process("hello world", context: makeContext(timings: timings))
        #expect(!result.corrections.isEmpty)
        #expect(result.corrections.first?.processorName == "PausePunctuation")
    }

    @Test func multipleInsertions() {
        // Text with multiple long pauses should get multiple punctuation marks.
        // Using 4 words with 2 long gaps. With <5 timings, default thresholds apply.
        let timings = [
            WordTimingInfo(word: "hello", start: 0.0, end: 0.5),
            WordTimingInfo(word: "there", start: 1.5, end: 2.0),
            WordTimingInfo(word: "good", start: 3.0, end: 3.5),
            WordTimingInfo(word: "morning", start: 3.6, end: 4.0),
        ]
        let result = processor.process("hello there good morning", context: makeContext(timings: timings)).text
        // Both "hello" and "there" should get punctuation after them
        // (gaps of 1.0s each, both >= sentenceBreak 0.8)
        let punctCount = result.filter { ".?!,".contains($0) }.count
        #expect(punctCount >= 2)
    }

    @Test func adaptiveThresholdsWithManyWords() {
        // 6+ word timings trigger adaptive thresholds.
        // Gaps: 0.1, 0.1, 0.1, 0.1, 2.0 → sorted [0.1, 0.1, 0.1, 0.1, 2.0]
        // median = 0.1, sentenceBreak = max(0.3, 0.5) = 0.5, clauseBreak = max(0.15, 0.2) = 0.2
        // Gap of 2.0 between word5 and word6 >= 0.5 → period inserted
        let timings = [
            WordTimingInfo(word: "the", start: 0.0, end: 0.1),
            WordTimingInfo(word: "quick", start: 0.2, end: 0.3),
            WordTimingInfo(word: "brown", start: 0.4, end: 0.5),
            WordTimingInfo(word: "fox", start: 0.6, end: 0.7),
            WordTimingInfo(word: "jumped", start: 0.8, end: 0.9),
            WordTimingInfo(word: "high", start: 2.9, end: 3.0),
        ]
        let result = processor.process("the quick brown fox jumped high", context: makeContext(timings: timings)).text
        // The big gap after "jumped" should insert punctuation
        #expect(result.contains(".") || result.contains(","))
    }
}
