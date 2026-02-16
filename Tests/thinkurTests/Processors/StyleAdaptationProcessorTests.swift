import Testing
@testable import thinkur

@Suite("StyleAdaptationProcessor")
struct StyleAdaptationProcessorTests {
    let processor = StyleAdaptationProcessor()

    private func ctx(style: AppStyle) -> ProcessingContext {
        ProcessingContext(
            frontmostAppBundleID: "com.test",
            frontmostAppName: "Test",
            wordTimings: [],
            appStyle: style
        )
    }

    // MARK: - Casual style

    @Test func casualStripsTrailingPeriod() {
        let result = processor.process("Hello there.", context: ctx(style: .casual))
        #expect(!result.hasSuffix("."))
    }

    @Test func casualLowercasesFirstChar() {
        let result = processor.process("Hello there", context: ctx(style: .casual))
        #expect(result.hasPrefix("h"))
    }

    @Test func casualPreservesIPronoun() {
        let result = processor.process("I think so", context: ctx(style: .casual))
        #expect(result.hasPrefix("I"))
    }

    @Test func casualDoesNotStripPeriodInMultiSentence() {
        let result = processor.process("First sentence. Second sentence.", context: ctx(style: .casual))
        // Contains ". " so period should be kept
        #expect(result.contains("."))
    }

    // MARK: - Formal style

    @Test func formalAddsTrailingPeriod() {
        let result = processor.process("Hello there", context: ctx(style: .formal))
        #expect(result.hasSuffix("."))
    }

    @Test func formalKeepsExistingPunctuation() {
        let result = processor.process("Hello there!", context: ctx(style: .formal))
        #expect(result.hasSuffix("!"))
    }

    // MARK: - Code style

    @Test func codeReturnsUnchanged() {
        let result = processor.process("let x = 5", context: ctx(style: .code))
        #expect(result == "let x = 5")
    }

    // MARK: - Standard style

    @Test func standardReturnsUnchanged() {
        let result = processor.process("Hello there.", context: ctx(style: .standard))
        #expect(result == "Hello there.")
    }

    // MARK: - Edge cases

    @Test func emptyString() {
        let result = processor.process("", context: ctx(style: .casual))
        #expect(result == "")
    }
}
