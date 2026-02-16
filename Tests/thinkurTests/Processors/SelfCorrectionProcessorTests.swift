import Testing
@testable import thinkur

@Suite("SelfCorrectionProcessor")
struct SelfCorrectionProcessorTests {
    let processor = SelfCorrectionProcessor()
    let ctx = ProcessingContext(
        frontmostAppBundleID: "com.test",
        frontmostAppName: "Test",
        wordTimings: [],
        appStyle: .standard
    )

    @Test func scratchThatRemovesPreviousClause() {
        let result = processor.process("I want pizza scratch that I want pasta", context: ctx)
        #expect(result == "I want pasta")
    }

    @Test func neverMindRemovesPreviousClause() {
        let result = processor.process("go left never mind go right", context: ctx)
        #expect(result == "go right")
    }

    @Test func iMeanCorrection() {
        let result = processor.process("it costs ten i mean twenty dollars", context: ctx)
        #expect(result == "twenty dollars")
    }

    @Test func actuallyNoCorrection() {
        let result = processor.process("let's do blue actually no let's do red", context: ctx)
        #expect(result == "let's do red")
    }

    @Test func noCorrectionPhrase() {
        let result = processor.process("hello world", context: ctx)
        #expect(result == "hello world")
    }

    @Test func emptyString() {
        let result = processor.process("", context: ctx)
        #expect(result == "")
    }

    @Test func correctionAfterSentenceBoundary() {
        let result = processor.process("first sentence. wrong part scratch that correct part", context: ctx)
        #expect(result.contains("first sentence."))
        #expect(result.contains("correct part"))
    }

    @Test func startOverCorrection() {
        let result = processor.process("wrong stuff start over correct stuff", context: ctx)
        #expect(result == "correct stuff")
    }
}
