import Testing
@testable import thinkur

@Suite("PostProcessing Integration")
struct PostProcessingIntegrationTests {
    private let pipeline = TextPostProcessor(processors: [
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

    // MARK: - Filler removal + punctuation

    @Test func fillerThenPunctuation() {
        let result = pipeline.process("um hello period world", context: ctx()).text
        #expect(!result.lowercased().contains("um"))
        #expect(result.contains("."))
        #expect(!result.contains("period"))
    }

    // MARK: - Spoken punctuation + capitalization

    @Test func punctuationThenCapitalization() {
        let result = pipeline.process("hello period world", context: ctx()).text
        // "period" → ".", then capitalization after "."
        #expect(result.contains("."))
        #expect(result.contains("World") || result.contains("world"))
    }

    // MARK: - No double punctuation from spoken + pause

    @Test func noDoublePunctuationFromSpokenAndPause() {
        // Spoken punctuation inserts a period, pause punctuation should NOT add another
        let timings: [WordTimingInfo] = [
            WordTimingInfo(word: "hello", start: 0.0, end: 0.3),
            WordTimingInfo(word: "period", start: 0.3, end: 0.6),
            WordTimingInfo(word: "world", start: 2.0, end: 2.3),
        ]
        let result = pipeline.process("hello period world", context: ctx(timings: timings)).text
        // Should not have ".." or ". ."
        #expect(!result.contains(".."))
        #expect(!result.contains(". ."))
    }

    // MARK: - Full pipeline with realistic utterance

    @Test func realisticDictation() {
        let input = "um so I went to the store period I bought uh twenty three apples"
        let result = pipeline.process(input, context: ctx()).text
        // Fillers removed
        #expect(!result.lowercased().contains(" um "))
        #expect(!result.lowercased().contains(" uh "))
        // Punctuation applied
        #expect(result.contains("."))
        // Number formatting (twenty three → 23)
        #expect(result.contains("23"))
        // Not empty
        #expect(!result.isEmpty)
    }

    // MARK: - Disabled processors respected

    @Test func disabledProcessorsSkipped() {
        let result = pipeline.process(
            "um hello period",
            context: ctx(),
            disabledProcessors: ["FillerRemoval"]
        ).text
        // Fillers should still be present since FillerRemoval is disabled
        #expect(result.lowercased().contains("um"))
        // But punctuation still applied
        #expect(result.contains("."))
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
        let result = pipeline.process("hello world", context: ctx(style: .casual)).text
        // Casual style: first char lowercase (unless special)
        let firstChar = result.first!
        #expect(firstChar.isLowercase)
    }

    // MARK: - Corrections accumulated across processors

    @Test func correctionsAccumulatedAcrossProcessors() {
        let result = pipeline.process("um hello period world", context: ctx())
        // Multiple processors should contribute corrections
        #expect(!result.corrections.isEmpty)
        let processorNames = Set(result.corrections.map(\.processorName))
        // At minimum, FillerRemoval and SpokenPunctuation should have corrections
        #expect(processorNames.contains("FillerRemoval"))
        #expect(processorNames.contains("SpokenPunctuation"))
    }

    // MARK: - Empty input passthrough

    @Test func emptyInputThroughFullPipeline() {
        let result = pipeline.process("", context: ctx())
        #expect(result.text == "")
        #expect(result.corrections.isEmpty)
    }

    // MARK: - Pipeline performance

    @Test func pipelinePerformanceUnder10ms() {
        let input = "um so I went to the store period I bought uh twenty three apples and it was great"
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
