import Testing
@testable import thinkur

@Suite("ListDetectionProcessor")
struct ListDetectionProcessorTests {
    let processor = ListDetectionProcessor()
    let ctx = ProcessingContext(
        frontmostAppBundleID: "com.test",
        frontmostAppName: "Test",
        wordTimings: [],
        appStyle: .standard
    )

    // MARK: - Basic edge cases

    @Test func emptyString() {
        let result = processor.process("", context: ctx).text
        #expect(result == "")
    }

    @Test func noListMarkers() {
        let result = processor.process("hello world", context: ctx).text
        #expect(result == "hello world")
    }

    @Test func singleMarkerNotEnough() {
        // Only one numbered marker — below minItemsForList=2, so unchanged
        let result = processor.process("number one apples", context: ctx).text
        #expect(result == "number one apples")
    }

    @Test func bareNumberSequenceRemainsText() {
        let text = "1 apples 2 bananas 3 pears"
        #expect(processor.process(text, context: ctx).text == text)
    }

    @Test func ordinalSequenceRemainsText() {
        let text = "third apples fourth bananas"
        #expect(processor.process(text, context: ctx).text == text)
    }

    // MARK: - Numbered list detection

    @Test func numberedList() {
        let result = processor.process("number one apples number two bananas", context: ctx).text
        #expect(result.contains("\n"))
        #expect(result.contains("1."))
        #expect(result.contains("2."))
        #expect(result.lowercased().contains("apples"))
        #expect(result.lowercased().contains("bananas"))
    }
    @Test func explicitNumberedListPreservesNonOneStartingValues() {
        let text = "step 3 apples step 4 bananas"
        let result = processor.process(text, context: ctx).text
        #expect(result.contains("3. Apples"))
        #expect(result.contains("4. Bananas"))
        #expect(!result.contains("1."))
        #expect(!result.contains("2."))
    }

    @Test func numberedListPreservesHigherSequentialStartingNumbers() {
        let text = "number 5 apples number 6 bananas"
        let result = processor.process(text, context: ctx).text
        #expect(result.contains("5. Apples"))
        #expect(result.contains("6. Bananas"))
    }

    @Test func bulletListWithOrdinalInContentPreserved() {
        let text = "bullet point call the third party bullet point send the invoice"
        let result = processor.process(text, context: ctx).text
        #expect(result.contains("• Call the third party"))
        #expect(result.contains("• Send the invoice"))
    }

    @Test func numberedListWithOrdinalInContentPreserved() {
        let text = "step 1 call the third party step 2 send the invoice"
        let result = processor.process(text, context: ctx).text
        #expect(result.contains("1. Call the third party"))
        #expect(result.contains("2. Send the invoice"))
    }

    @Test func mixedMarkersPreserveIndividualCategories() {
        let text = "step 1 apples bullet point bananas"
        let result = processor.process(text, context: ctx)
        #expect(result.text.contains("1. Apples"))
        #expect(result.text.contains("• Bananas"))
        #expect(result.corrections.contains { $0.ruleName == "list_numbered" })
        #expect(result.corrections.contains { $0.ruleName == "list_bullet" })
    }

    @Test func mixedMarkersBulletThenNumberedPreserved() {
        let text = "bullet point apples step 2 bananas"
        let result = processor.process(text, context: ctx)
        #expect(result.text.contains("• Apples"))
        #expect(result.text.contains("2. Bananas"))
    }

    @Test func spokenNumberSpansPreservedAsText() {
        let text = "one through four"
        #expect(processor.process(text, context: ctx).text == text)
        let ordinals = "third or fourth"
        #expect(processor.process(ordinals, context: ctx).text == ordinals)
    }

    // MARK: - Bullet list detection

    @Test func bulletList() {
        let result = processor.process("bullet point apples bullet point bananas", context: ctx).text
        #expect(result.contains("\n"))
        #expect(result.contains("• ") || result.contains("- "))
        #expect(result.lowercased().contains("apples"))
        #expect(result.lowercased().contains("bananas"))
    }

    // MARK: - Code style skips list detection

    @Test func codeStyleSkipsList() {
        let codeCtx = ProcessingContext(
            frontmostAppBundleID: "com.apple.dt.Xcode",
            frontmostAppName: "Xcode",
            wordTimings: [],
            appStyle: .code
        )
        let result = processor.process("number one apples number two bananas", context: codeCtx).text
        // In code context, list detection is skipped — text remains unchanged
        #expect(result == "number one apples number two bananas")
    }

    // MARK: - Ordinal disambiguation

    @Test func narrativeOrdinalPreserved() {
        // "the first time I went" triggers narrative disambiguation — not a list
        let result = processor.process("the first time I went the second time I stayed", context: ctx).text
        #expect(result == "the first time I went the second time I stayed")
    }

    // MARK: - Correction metadata

    @Test func correctionMetadata() {
        let result = processor.process("number one apples number two bananas", context: ctx)
        #expect(!result.corrections.isEmpty)
        #expect(result.corrections.allSatisfy { $0.processorName == "ListDetection" })
    }
}
