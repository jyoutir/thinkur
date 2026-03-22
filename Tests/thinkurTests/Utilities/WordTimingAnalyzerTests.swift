import Testing
@testable import thinkur

@Suite("WordTimingAnalyzer")
struct WordTimingAnalyzerTests {
    @Test func gapsReturnsCorrectGapsBetweenTimings() {
        let timings = [
            WordTimingInfo(word: "hello", start: 0.0, end: 0.5),
            WordTimingInfo(word: "world", start: 1.0, end: 1.5),
            WordTimingInfo(word: "foo", start: 2.5, end: 3.0),
        ]
        let gaps = WordTimingAnalyzer.gaps(from: timings)
        #expect(gaps.count == 2)
        #expect(gaps[0].gap == 0.5 as Float)
        #expect(gaps[0].wordBefore == "hello")
        #expect(gaps[0].wordAfter == "world")
        #expect(gaps[1].gap == 1.0 as Float)
    }

    @Test func gapsReturnsEmptyForFewerThanTwoTimings() {
        let single = [WordTimingInfo(word: "hello", start: 0.0, end: 0.5)]
        #expect(WordTimingAnalyzer.gaps(from: single).isEmpty)
        #expect(WordTimingAnalyzer.gaps(from: []).isEmpty)
    }

    @Test func medianGapReturnsMedianOfPositiveGaps() {
        let timings = [
            WordTimingInfo(word: "a", start: 0.0, end: 0.5),
            WordTimingInfo(word: "b", start: 1.0, end: 1.5),
            WordTimingInfo(word: "c", start: 1.75, end: 2.0),
            WordTimingInfo(word: "d", start: 3.0, end: 3.5),
        ]
        // Gaps: 0.5, 0.25, 1.0 -> sorted: 0.25, 0.5, 1.0 -> median at index 1 = 0.5
        let median = WordTimingAnalyzer.medianGap(from: timings)
        #expect(median == 0.5 as Float)
    }
}
