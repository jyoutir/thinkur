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

    // MARK: - Numbered list detection

    @Test func numberedList() {
        let result = processor.process("number one apples number two bananas", context: ctx).text
        #expect(result.contains("\n"))
        #expect(result.contains("1."))
        #expect(result.contains("2."))
        #expect(result.contains("apples"))
        #expect(result.contains("bananas"))
    }

    // MARK: - Bullet list detection

    @Test func bulletList() {
        let result = processor.process("bullet point apples bullet point bananas", context: ctx).text
        #expect(result.contains("\n"))
        #expect(result.contains("- "))
        #expect(result.contains("apples"))
        #expect(result.contains("bananas"))
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
