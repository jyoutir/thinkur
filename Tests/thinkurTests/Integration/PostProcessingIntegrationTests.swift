import Testing
@testable import thinkur

@Suite("PostProcessing Integration")
struct PostProcessingIntegrationTests {
    private let pipeline = TextPostProcessor(processors: [
        SelfCorrectionProcessor(),
        FillerRemovalProcessor(),
        SmartFormattingProcessor(),
        StyleAdaptationProcessor(),
        ListDetectionProcessor(),
        CodeContextProcessor(),
    ])

    private func ctx(
        style: AppStyle = .standard,
        timings: [WordTimingInfo] = []
    ) -> ProcessingContext {
        ProcessingContext(
            frontmostAppBundleID: style == .code ? "com.apple.dt.Xcode" : "com.test",
            frontmostAppName: style == .code ? "Xcode" : "Test",
            wordTimings: timings,
            appStyle: style
        )
    }

    // MARK: - Self-Correction + Filler Removal interaction

    @Test func selfCorrectionThenFillerRemoval() {
        // "I mean" triggers self-correction, "um" is a filler
        let result = pipeline.process("um hello I mean goodbye", context: ctx()).text
        // Filler "um" removed, self-correction "I mean" replaces "hello" with "goodbye"
        #expect(!result.lowercased().contains("um"))
        #expect(result.lowercased().contains("goodbye"))
    }

    // MARK: - Filler removal + number formatting

    @Test func fillerThenNumberFormatting() {
        let result = pipeline.process("um I bought twenty three apples", context: ctx()).text
        #expect(!result.lowercased().contains("um"))
        #expect(result.contains("23"))
    }

    // MARK: - Full pipeline with realistic utterance

    @Test func realisticDictation() {
        let input = "um so I went to the store. I bought uh twenty three apples"
        let result = pipeline.process(input, context: ctx()).text
        // Fillers removed
        #expect(!result.lowercased().contains(" um "))
        #expect(!result.lowercased().contains(" uh "))
        // Number formatting (twenty three → 23)
        #expect(result.contains("23"))
        // Not empty
        #expect(!result.isEmpty)
    }

    // MARK: - Disabled processors respected

    @Test func disabledProcessorsSkipped() {
        let result = pipeline.process(
            "um hello world",
            context: ctx(),
            disabledProcessors: ["FillerRemoval"]
        ).text
        // Fillers should still be present since FillerRemoval is disabled
        #expect(result.lowercased().contains("um"))
    }

    // MARK: - Code context isolated from standard

    @Test func codeProcessorsOnlyInCodeContext() {
        let standardResult = pipeline.process("comment hello world", context: ctx(style: .standard)).text
        let codeResult = pipeline.process("comment hello world", context: ctx(style: .code)).text
        // In standard mode, "comment" should remain as-is
        #expect(standardResult.lowercased().contains("comment"))
        // In code mode, "comment" should produce "//"
        #expect(codeResult.contains("//"))
    }

    // MARK: - Style adaptation applies last

    @Test func casualStyleLowersFirstChar() {
        let result = pipeline.process("Hello world", context: ctx(style: .casual)).text
        // Casual style: first char lowercase (unless special)
        let firstChar = result.first!
        #expect(firstChar.isLowercase)
    }

    // MARK: - Corrections accumulated across processors

    @Test func correctionsAccumulatedAcrossProcessors() {
        let result = pipeline.process("um hello world", context: ctx())
        // FillerRemoval should contribute corrections
        #expect(!result.corrections.isEmpty)
        let processorNames = Set(result.corrections.map(\.processorName))
        #expect(processorNames.contains("FillerRemoval"))
    }

    // MARK: - Empty input passthrough

    @Test func emptyInputThroughFullPipeline() {
        let result = pipeline.process("", context: ctx())
        #expect(result.text == "")
        #expect(result.corrections.isEmpty)
    }

    // MARK: - Pipeline performance

    @Test func pipelinePerformanceUnder10ms() {
        let input = "um so I went to the store. I bought uh twenty three apples and it was great"
        let start = ContinuousClock.now
        for _ in 0..<100 {
            _ = pipeline.process(input, context: ctx())
        }
        let elapsed = ContinuousClock.now - start
        let perCall = elapsed / 100
        // Each call should be under 10ms
        #expect(perCall < .milliseconds(10))
    }
}
