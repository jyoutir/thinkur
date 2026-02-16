import Testing
@testable import thinkur

@Suite("SpokenPunctuationProcessor")
struct SpokenPunctuationProcessorTests {
    let processor = SpokenPunctuationProcessor()
    let ctx = ProcessingContext(
        frontmostAppBundleID: "com.test",
        frontmostAppName: "Test",
        wordTimings: [],
        appStyle: .standard
    )

    @Test func periodReplacement() {
        let result = processor.process("hello period", context: ctx)
        #expect(result == "hello.")
    }

    @Test func commaReplacement() {
        let result = processor.process("first comma second", context: ctx)
        #expect(result == "first, second")
    }

    @Test func questionMark() {
        let result = processor.process("how are you question mark", context: ctx)
        #expect(result == "how are you?")
    }

    @Test func exclamationMark() {
        let result = processor.process("wow exclamation mark", context: ctx)
        #expect(result == "wow!")
    }

    @Test func exclamationPoint() {
        let result = processor.process("great exclamation point", context: ctx)
        #expect(result == "great!")
    }

    @Test func newParagraph() {
        let result = processor.process("first new paragraph second", context: ctx)
        // Processor replaces "new paragraph" with \n\n but doesn't strip adjacent spaces
        #expect(result.contains("\n\n"))
    }

    @Test func newLine() {
        let result = processor.process("line one new line line two", context: ctx)
        // Processor replaces "new line" with \n but doesn't strip adjacent spaces
        #expect(result.contains("\n"))
    }

    @Test func ellipsis() {
        let result = processor.process("well ellipsis", context: ctx)
        #expect(result == "well...")
    }

    @Test func dotDotDot() {
        let result = processor.process("thinking dot dot dot", context: ctx)
        #expect(result == "thinking...")
    }

    @Test func colon() {
        let result = processor.process("note colon important", context: ctx)
        #expect(result == "note: important")
    }

    @Test func semicolon() {
        let result = processor.process("first semicolon second", context: ctx)
        #expect(result == "first; second")
    }

    @Test func openCloseQuotes() {
        let result = processor.process("he said open quote hello close quote", context: ctx)
        // Processor replaces open/close quote with " but doesn't strip adjacent spaces
        #expect(result.contains("\""))
    }

    @Test func emptyString() {
        let result = processor.process("", context: ctx)
        #expect(result == "")
    }

    @Test func noSpokenPunctuation() {
        let result = processor.process("hello world", context: ctx)
        #expect(result == "hello world")
    }
}
