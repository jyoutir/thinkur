import Testing
@testable import thinkur

@Suite("PauseThresholds")
struct PauseThresholdsTests {
    @Test func defaultValues() {
        let defaults = PauseThresholds.default
        #expect(defaults.sentenceBreak == 1.5 as Float)
        #expect(defaults.clauseBreak == 0.4 as Float)
    }

    @Test func adaptiveWithFewerThanFiveTimingsReturnsDefaults() {
        let timings = [
            WordTimingInfo(word: "a", start: 0.0, end: 0.5),
            WordTimingInfo(word: "b", start: 1.0, end: 1.5),
            WordTimingInfo(word: "c", start: 2.0, end: 2.5),
        ]
        let result = PauseThresholds.adaptive(from: timings)
        #expect(result.sentenceBreak == PauseThresholds.default.sentenceBreak)
        #expect(result.clauseBreak == PauseThresholds.default.clauseBreak)
    }

    @Test func adaptiveWithEnoughTimingsComputesBasedOnMedian() {
        let timings = [
            WordTimingInfo(word: "a", start: 0.0, end: 0.5),
            WordTimingInfo(word: "b", start: 1.0, end: 1.5),
            WordTimingInfo(word: "c", start: 2.0, end: 2.5),
            WordTimingInfo(word: "d", start: 3.0, end: 3.5),
            WordTimingInfo(word: "e", start: 4.0, end: 4.5),
        ]
        // Gaps: 0.5, 0.5, 0.5, 0.5 -> sorted: all 0.5 -> median = 0.5
        // sentenceBreak = max(0.5 * 3.0, 1.0) = 1.5
        // clauseBreak = max(0.5 * 1.5, 0.2) = 0.75
        let result = PauseThresholds.adaptive(from: timings)
        #expect(result.sentenceBreak == 1.5 as Float)
        #expect(result.clauseBreak == 0.75 as Float)
    }
}
