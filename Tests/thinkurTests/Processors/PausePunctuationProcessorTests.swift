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

    @Test func longPauseInsertsPeriod() {
        let timings = [
            WordTimingInfo(word: "hello", start: 0.0, end: 0.5),
            WordTimingInfo(word: "world", start: 1.5, end: 2.0),
        ]
        let result = processor.process("hello world", context: makeContext(timings: timings))
        #expect(result.contains("."))
    }

    @Test func shortPauseInsertsComma() {
        let timings = [
            WordTimingInfo(word: "hello", start: 0.0, end: 0.5),
            WordTimingInfo(word: "world", start: 1.0, end: 1.5),
        ]
        let result = processor.process("hello world", context: makeContext(timings: timings))
        #expect(result.contains(","))
    }

    @Test func noPauseNoPunctuation() {
        let timings = [
            WordTimingInfo(word: "hello", start: 0.0, end: 0.3),
            WordTimingInfo(word: "world", start: 0.35, end: 0.65),
        ]
        let result = processor.process("hello world", context: makeContext(timings: timings))
        #expect(!result.contains(".") && !result.contains(","))
    }

    @Test func emptyTimingsReturnsOriginal() {
        let result = processor.process("hello world", context: makeContext(timings: []))
        #expect(result == "hello world")
    }

    @Test func singleWordReturnsOriginal() {
        let timings = [WordTimingInfo(word: "hello", start: 0.0, end: 0.5)]
        let result = processor.process("hello", context: makeContext(timings: timings))
        #expect(result == "hello")
    }

    @Test func questionWordAfterPause() {
        let timings = [
            WordTimingInfo(word: "ok", start: 0.0, end: 0.3),
            WordTimingInfo(word: "what", start: 1.5, end: 1.8),
            WordTimingInfo(word: "happened", start: 1.9, end: 2.3),
        ]
        let result = processor.process("ok what happened", context: makeContext(timings: timings))
        // "what" is a question starter, so the clause should end with "?"
        #expect(result.contains("?"))
    }

    @Test func existingPunctuationNotDuplicated() {
        let timings = [
            WordTimingInfo(word: "hello.", start: 0.0, end: 0.5),
            WordTimingInfo(word: "world", start: 1.5, end: 2.0),
        ]
        let result = processor.process("hello. world", context: makeContext(timings: timings))
        // Should not add double punctuation
        #expect(!result.contains(".."))
    }
}
