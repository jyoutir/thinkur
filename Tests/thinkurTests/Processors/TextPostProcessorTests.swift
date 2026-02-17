import Testing
@testable import thinkur

@Suite("TextPostProcessor Pipeline")
struct TextPostProcessorTests {
    let ctx = ProcessingContext(
        frontmostAppBundleID: "com.test",
        frontmostAppName: "Test",
        wordTimings: [],
        appStyle: .standard
    )

    @Test func emptyPipelineReturnsOriginal() {
        let pipeline = TextPostProcessor(processors: [])
        let result = pipeline.process("hello world", context: ctx).text
        #expect(result == "hello world")
    }

    @Test func singleProcessorApplied() {
        let pipeline = TextPostProcessor(processors: [SpokenPunctuationProcessor()])
        let result = pipeline.process("hello period", context: ctx).text
        #expect(result == "hello.")
    }

    @Test func processorsApplyInOrder() {
        // SpokenPunctuation first converts "period" to ".", then Capitalization capitalizes after "."
        let pipeline = TextPostProcessor(processors: [
            SpokenPunctuationProcessor(),
            CapitalizationProcessor(),
        ])
        let result = pipeline.process("hello period world", context: ctx).text
        #expect(result == "Hello. World")
    }

    @Test func fullPipelineDoesNotCrash() {
        let pipeline = TextPostProcessor(processors: [
            SelfCorrectionProcessor(),
            FillerRemovalProcessor(),
            SpokenPunctuationProcessor(),
            SmartFormattingProcessor(),
            PausePunctuationProcessor(),
            CapitalizationProcessor(),
            StyleAdaptationProcessor(),
            ListDetectionProcessor(),
            CodeContextProcessor(),
        ])
        let result = pipeline.process("um hello period world", context: ctx).text
        #expect(!result.isEmpty)
    }

    @Test func pipelineWithFillerThenPunctuation() {
        let pipeline = TextPostProcessor(processors: [
            FillerRemovalProcessor(),
            SpokenPunctuationProcessor(),
        ])
        let result = pipeline.process("um hello period", context: ctx).text
        #expect(result == "hello.")
    }
}
