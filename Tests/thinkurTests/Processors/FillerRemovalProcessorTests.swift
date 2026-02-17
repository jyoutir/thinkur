import Testing
@testable import thinkur

@Suite("FillerRemovalProcessor")
struct FillerRemovalProcessorTests {
    let processor = FillerRemovalProcessor()
    let ctx = ProcessingContext(
        frontmostAppBundleID: "com.test",
        frontmostAppName: "Test",
        wordTimings: [],
        appStyle: .standard
    )

    // MARK: - Existing tests

    @Test func removesSingleFillers() {
        let result = processor.process("um I think uh that works", context: ctx).text
        #expect(result == "I think that works")
    }

    @Test func removesMultiWordFillers() {
        let result = processor.process("I you know went to the store", context: ctx).text
        #expect(result == "I went to the store")
    }

    @Test func removesHmm() {
        let result = processor.process("hmm the meeting is tomorrow", context: ctx).text
        #expect(result == "the meeting is tomorrow")
    }

    @Test func emptyString() {
        let result = processor.process("", context: ctx).text
        #expect(result == "")
    }

    @Test func noFillers() {
        let result = processor.process("I went to the store", context: ctx).text
        #expect(result == "I went to the store")
    }

    @Test func allFillers() {
        let result = processor.process("um uh er", context: ctx).text
        #expect(result == "")
    }

    @Test func preservesLegitimateWords() {
        // "like" as verb should be preserved (context-dependent via NLTagger)
        let result = processor.process("I like pizza", context: ctx).text
        // NLTagger should tag "like" as verb here
        #expect(result.contains("like") || result == "I pizza")
        // At minimum, should not crash
    }

    // MARK: - New tests: hesitation filler variants

    @Test func removesUmm() {
        let result = processor.process("umm I was saying", context: ctx).text
        #expect(result == "I was saying")
    }

    @Test func removesUhh() {
        let result = processor.process("uhhh the point is", context: ctx).text
        #expect(result == "the point is")
    }

    @Test func removesEr() {
        let result = processor.process("the answer is er correct", context: ctx).text
        #expect(result == "the answer is correct")
    }

    @Test func removesErm() {
        let result = processor.process("erm what was I saying", context: ctx).text
        #expect(result == "what was I saying")
    }

    @Test func removesMultipleHesitations() {
        let result = processor.process("um uh er the meeting", context: ctx).text
        #expect(result == "the meeting")
    }

    // MARK: - New tests: multi-word filler removal

    @Test func removesYouKnowWhat() {
        let result = processor.process("I was you know what thinking about it", context: ctx).text
        #expect(result == "I was thinking about it")
    }

    @Test func removesOrSomething() {
        let result = processor.process("we could go to the park or something", context: ctx).text
        #expect(result == "we could go to the park")
    }

    @Test func removesAndStuff() {
        let result = processor.process("I bought groceries and stuff", context: ctx).text
        #expect(result == "I bought groceries")
    }

    @Test func removesToBeHonest() {
        let result = processor.process("to be honest I don't care", context: ctx).text
        #expect(result == "I don't care")
    }

    @Test func removesLetMeThink() {
        let result = processor.process("let me think the answer is five", context: ctx).text
        #expect(result == "the answer is five")
    }

    @Test func removesIfYouWill() {
        let result = processor.process("it was a masterpiece if you will", context: ctx).text
        #expect(result == "it was a masterpiece")
    }

    // MARK: - New tests: "like" disambiguation

    @Test func removesLikeAsFiller() {
        let result = processor.process("I was like going to the store", context: ctx).text
        #expect(result == "I was going to the store")
    }

    @Test func preservesLikeAsVerb() {
        let result = processor.process("I like this movie", context: ctx).text
        #expect(result == "I like this movie")
    }

    @Test func preservesLookLike() {
        let result = processor.process("it looks like rain", context: ctx).text
        #expect(result.contains("like"))
    }

    // MARK: - New tests: discourse marker disambiguation

    @Test func preservesWellAdjective() {
        let result = processor.process("I'm not feeling well", context: ctx).text
        #expect(result.contains("well"))
    }

    @Test func preservesAsWell() {
        let result = processor.process("I'll have that as well", context: ctx).text
        #expect(result.contains("as well"))
    }

    @Test func preservesSoIntensifier() {
        let result = processor.process("I was so happy", context: ctx).text
        #expect(result.contains("so happy"))
    }

    @Test func preservesSoConjunction() {
        let result = processor.process("I was tired so I slept", context: ctx).text
        #expect(result.contains("so"))
    }

    @Test func preservesOkayAdjective() {
        let result = processor.process("it's okay to fail", context: ctx).text
        #expect(result.contains("okay"))
    }

    // MARK: - New tests: verbal tic removal

    @Test func removesVerbalTics() {
        let result = processor.process("oops I dropped it", context: ctx).text
        #expect(result == "I dropped it")
    }

    // MARK: - New tests: correction metadata

    @Test func correctionMetadata() {
        let result = processor.process("um I think uh that works", context: ctx)
        #expect(!result.corrections.isEmpty)
    }
}
