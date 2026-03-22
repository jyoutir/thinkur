import Testing
@testable import thinkur

@Suite("SentenceBoundaryMatcher")
struct SentenceBoundaryMatcherTests {
    @Test func returnsNoBoundariesForShortText() {
        let result = SentenceBoundaryMatcher.findBoundaries(in: "hello world bye")
        #expect(result.isEmpty)
    }

    @Test func detectsContractionRestarter() {
        let text = "the meeting went well I'm going to follow up"
        let boundaries = SentenceBoundaryMatcher.findBoundaries(in: text)
        let boundaryWords = boundaries.map { String(text[$0...].prefix(while: { $0 != " " })) }
        #expect(boundaryWords.contains("I'm"))
    }

    @Test func detectsSubjectPronounI() {
        let text = "the project is done I need to review it"
        let boundaries = SentenceBoundaryMatcher.findBoundaries(in: text)
        let boundaryWords = boundaries.map { String(text[$0...].prefix(while: { $0 != " " })) }
        #expect(boundaryWords.contains("I"))
    }

    @Test func doesNotBreakAfterJoiningWord() {
        let text = "the project is good and I will continue working"
        let boundaries = SentenceBoundaryMatcher.findBoundaries(in: text)
        let boundaryWords = boundaries.map { String(text[$0...].prefix(while: { $0 != " " })) }
        #expect(!boundaryWords.contains("I"))
    }

    @Test func doesNotBreakAfterIncompleteEnder() {
        let text = "today we will probably I think reconsider things"
        let boundaries = SentenceBoundaryMatcher.findBoundaries(in: text)
        // "I" follows "probably" which is not in incompleteEnders, but "probably" isn't a joining word either.
        // Check that "will" as an incomplete ender would block: use direct test
        let text2 = "the system will I think handle it properly"
        let boundaries2 = SentenceBoundaryMatcher.findBoundaries(in: text2)
        let words2 = boundaries2.map { String(text2[$0...].prefix(while: { $0 != " " })) }
        #expect(!words2.contains("I"))
    }

    @Test func detectsGreetingStarter() {
        let text = "the report is ready thank you for your help"
        let boundaries = SentenceBoundaryMatcher.findBoundaries(in: text)
        let boundaryWords = boundaries.map { String(text[$0...].prefix(while: { $0 != " " })) }
        #expect(boundaryWords.contains("thank"))
    }

    @Test func detectsDiscourseMarkerAfterSufficientContent() {
        let text = "we finished the entire project however we need more time"
        let boundaries = SentenceBoundaryMatcher.findBoundaries(in: text)
        let boundaryWords = boundaries.map { String(text[$0...].prefix(while: { $0 != " " })) }
        #expect(boundaryWords.contains("however"))
    }

    @Test func discourseMarkerNeedsAtLeastFourWordsBefore() {
        let text = "we finished it however we need more time"
        let boundaries = SentenceBoundaryMatcher.findBoundaries(in: text)
        let boundaryWords = boundaries.map { String(text[$0...].prefix(while: { $0 != " " })) }
        // "however" is at word index 3, needs wordsBefore >= 4
        #expect(!boundaryWords.contains("however"))
    }

    @Test func returnsEmptyForEmptyString() {
        let result = SentenceBoundaryMatcher.findBoundaries(in: "")
        #expect(result.isEmpty)
    }

    @Test func detectsLetContraction() {
        let text = "the food was really great let's go somewhere else"
        let boundaries = SentenceBoundaryMatcher.findBoundaries(in: text)
        let boundaryWords = boundaries.map { String(text[$0...].prefix(while: { $0 != " " })) }
        #expect(boundaryWords.contains("let's"))
    }
}
