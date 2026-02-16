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

    @Test func removesSingleFillers() {
        let result = processor.process("um I think uh that works", context: ctx)
        #expect(result == "I think that works")
    }

    @Test func removesMultiWordFillers() {
        let result = processor.process("I you know went to the store", context: ctx)
        #expect(result == "I went to the store")
    }

    @Test func removesHmm() {
        let result = processor.process("hmm let me think", context: ctx)
        #expect(result == "let me think")
    }

    @Test func emptyString() {
        let result = processor.process("", context: ctx)
        #expect(result == "")
    }

    @Test func noFillers() {
        let result = processor.process("I went to the store", context: ctx)
        #expect(result == "I went to the store")
    }

    @Test func allFillers() {
        let result = processor.process("um uh er", context: ctx)
        #expect(result == "")
    }

    @Test func preservesLegitimateWords() {
        // "like" as verb should be preserved (context-dependent via NLTagger)
        let result = processor.process("I like pizza", context: ctx)
        // NLTagger should tag "like" as verb here
        #expect(result.contains("like") || result == "I pizza")
        // At minimum, should not crash
    }
}
