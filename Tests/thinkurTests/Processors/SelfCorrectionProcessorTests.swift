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

    // MARK: - Existing tests

    @Test func scratchThatRemovesPreviousClause() {
        let result = processor.process("I want pizza scratch that I want pasta", context: ctx).text
        #expect(result == "I want pasta")
    }

    @Test func neverMindRemovesPreviousClause() {
        let result = processor.process("go left never mind go right", context: ctx).text
        #expect(result == "go right")
    }

    @Test func iMeanCorrection() {
        let result = processor.process("it costs ten i mean twenty dollars", context: ctx).text
        #expect(result == "twenty dollars")
    }

    @Test func actuallyNoCorrection() {
        let result = processor.process("let's do blue actually no let's do red", context: ctx).text
        #expect(result == "let's do red")
    }

    @Test func noCorrectionPhrase() {
        let result = processor.process("hello world", context: ctx).text
        #expect(result == "hello world")
    }

    @Test func emptyString() {
        let result = processor.process("", context: ctx).text
        #expect(result == "")
    }

    @Test func correctionAfterSentenceBoundary() {
        let result = processor.process("first sentence. wrong part scratch that correct part", context: ctx).text
        #expect(result.contains("first sentence."))
        #expect(result.contains("correct part"))
    }

    @Test func startOverCorrection() {
        let result = processor.process("wrong stuff start over correct stuff", context: ctx).text
        #expect(result == "correct stuff")
    }

    // MARK: - New tests: explicit correction phrases

    @Test func deleteThatCorrection() {
        let result = processor.process("this is wrong delete that the answer is 42", context: ctx).text
        #expect(result == "the answer is 42")
    }

    @Test func strikeThat() {
        let result = processor.process("old text strike that new text", context: ctx).text
        #expect(result == "new text")
    }

    @Test func disregardThat() {
        let result = processor.process("I think disregard that I know the answer", context: ctx).text
        #expect(result == "I know the answer")
    }

    @Test func forgetThat() {
        let result = processor.process("wrong answer forget that right answer", context: ctx).text
        #expect(result == "right answer")
    }

    @Test func eraseThatCorrection() {
        let result = processor.process("bad text erase that good text", context: ctx).text
        #expect(result == "good text")
    }

    // MARK: - New tests: medium-confidence correction phrases

    @Test func waitNoCorrection() {
        let result = processor.process("send it to John wait no send it to Sarah", context: ctx).text
        #expect(result == "send it to Sarah")
    }

    @Test func noWaitCorrection() {
        let result = processor.process("call them no wait text them", context: ctx).text
        #expect(result == "text them")
    }

    @Test func orRatherCorrection() {
        let result = processor.process("send it to John or rather Sarah", context: ctx).text
        #expect(result.contains("Sarah"))
    }

    @Test func wellActuallyCorrection() {
        let result = processor.process("the price is ten well actually twelve dollars", context: ctx).text
        #expect(result.contains("twelve dollars"))
    }

    @Test func whatIMeantWas() {
        let result = processor.process("it costs ten what i meant was twenty dollars", context: ctx).text
        #expect(result.contains("twenty"))
    }

    @Test func iMeantToSay() {
        let result = processor.process("send to John i meant to say Sarah", context: ctx).text
        #expect(result.contains("Sarah"))
    }

    @Test func sorryIMeant() {
        let result = processor.process("the answer is five sorry i meant six", context: ctx).text
        #expect(result.contains("six"))
    }

    // MARK: - New tests: multiple corrections and sentence preservation

    @Test func multipleCorrections() {
        let result = processor.process("send to John wait no send to Sarah", context: ctx).text
        #expect(result == "send to Sarah")
    }

    @Test func correctionPreservesOtherSentences() {
        let result = processor.process("hello. wrong scratch that right", context: ctx).text
        #expect(result.hasPrefix("hello."))
        #expect(result.contains("right"))
    }

    // MARK: - New tests: stutter/repeated word removal

    @Test func stutterRemoval() {
        let result = processor.process("I I went to the store", context: ctx).text
        #expect(result == "I went to the store")
    }

    @Test func repeatedWordRemoval() {
        let result = processor.process("the the meeting is tomorrow", context: ctx).text
        #expect(result == "the meeting is tomorrow")
    }

    @Test func preserveIntentionalRepetition() {
        let result = processor.process("it was very very good", context: ctx).text
        #expect(result == "it was very very good")
    }

    // MARK: - New tests: disambiguation (non-correction uses)

    @Test func iMeanGenuine() {
        let result = processor.process("I mean it when I say thank you", context: ctx).text
        #expect(result.contains("mean"))
        #expect(result.contains("it"))
    }

    @Test func actuallyGenuine() {
        let result = processor.process("I actually went to the store", context: ctx).text
        #expect(result.contains("actually"))
    }

    @Test func waitGenuine() {
        let result = processor.process("wait for me", context: ctx).text
        #expect(result == "wait for me")
    }

    // MARK: - New tests: no no no and correction metadata

    @Test func noNoNoCorrection() {
        let result = processor.process("wrong no no no right answer", context: ctx).text
        #expect(result == "right answer")
    }

    @Test func correctionMetadata() {
        let result = processor.process("I want pizza scratch that I want pasta", context: ctx)
        #expect(!result.corrections.isEmpty)
    }

    // MARK: - Regression: false positive prevention

    @Test func noAsAnswerPreserved() {
        let result = processor.process("no I don't think that's the right approach", context: ctx).text
        #expect(result.lowercased().contains("no"))
        #expect(result.contains("don't think"))
    }

    @Test func sorryAsApologyPreserved() {
        let result = processor.process("sorry I'm late the traffic was terrible", context: ctx).text
        #expect(result.lowercased().contains("sorry"))
        #expect(result.contains("late"))
    }

    @Test func selfCorrectionHyphenatedWordPreserved() {
        // "correction" inside "self-correction" should NOT trigger
        let result = processor.process("the self correction rules based system works well", context: ctx).text
        #expect(result.contains("self correction"))
        #expect(result.contains("rules based system"))
    }

    @Test func noRushPreserved() {
        let result = processor.process("no rush or anything", context: ctx).text
        #expect(result.contains("no rush"))
    }

    @Test func noActuallyInlineCorrection() {
        let input = "i talked to sarah and she said tuesday no actually wednesday"
        let result = processor.process(input, context: ctx)
        #expect(!result.corrections.isEmpty, "Expected corrections but got none. Text: \(result.text)")
        #expect(result.text == "i talked to sarah and she said wednesday", "Expected structural boundary correction but got: '\(result.text)'")
    }
}
