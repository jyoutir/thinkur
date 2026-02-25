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
        let pipeline = TextPostProcessor(processors: [FillerRemovalProcessor()])
        let result = pipeline.process("um hello world", context: ctx).text
        #expect(result == "hello world")
    }

    @Test func processorsApplyInOrder() {
        // FillerRemoval first removes "um", then SmartFormatting formats numbers
        let pipeline = TextPostProcessor(processors: [
            FillerRemovalProcessor(),
            SmartFormattingProcessor(),
        ])
        let result = pipeline.process("um twenty three apples", context: ctx).text
        #expect(result == "23 apples")
    }

    @Test func fullPipelineDoesNotCrash() {
        let pipeline = TextPostProcessor(processors: [
            SelfCorrectionProcessor(),
            FillerRemovalProcessor(),
            SmartFormattingProcessor(),
            StyleAdaptationProcessor(),
            ListDetectionProcessor(),
            CodeContextProcessor(),
        ])
        let result = pipeline.process("um hello world", context: ctx).text
        #expect(!result.isEmpty)
    }

    @Test func pipelineWithFillerThenFormatting() {
        let pipeline = TextPostProcessor(processors: [
            FillerRemovalProcessor(),
            SmartFormattingProcessor(),
        ])
        let result = pipeline.process("um twenty three", context: ctx).text
        #expect(result == "23")
    }
}
