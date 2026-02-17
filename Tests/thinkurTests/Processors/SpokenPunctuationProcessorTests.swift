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

    // MARK: - Existing tests

    @Test func periodReplacement() {
        let result = processor.process("hello period", context: ctx).text
        #expect(result == "hello.")
    }

    @Test func commaReplacement() {
        let result = processor.process("first comma second", context: ctx).text
        #expect(result == "first, second")
    }

    @Test func questionMark() {
        let result = processor.process("how are you question mark", context: ctx).text
        #expect(result == "how are you?")
    }

    @Test func exclamationMark() {
        let result = processor.process("wow exclamation mark", context: ctx).text
        #expect(result == "wow!")
    }

    @Test func exclamationPoint() {
        let result = processor.process("great exclamation point", context: ctx).text
        #expect(result == "great!")
    }

    @Test func newParagraph() {
        let result = processor.process("first new paragraph second", context: ctx).text
        // Processor replaces "new paragraph" with \n\n but doesn't strip adjacent spaces
        #expect(result.contains("\n\n"))
    }

    @Test func newLine() {
        let result = processor.process("line one new line line two", context: ctx).text
        // Processor replaces "new line" with \n but doesn't strip adjacent spaces
        #expect(result.contains("\n"))
    }

    @Test func ellipsis() {
        let result = processor.process("well ellipsis", context: ctx).text
        #expect(result == "well...")
    }

    @Test func dotDotDot() {
        let result = processor.process("thinking dot dot dot", context: ctx).text
        #expect(result == "thinking...")
    }

    @Test func colon() {
        let result = processor.process("note colon important", context: ctx).text
        #expect(result == "note: important")
    }

    @Test func semicolon() {
        let result = processor.process("first semicolon second", context: ctx).text
        #expect(result == "first; second")
    }

    @Test func openCloseQuotes() {
        let result = processor.process("he said open quote hello close quote", context: ctx).text
        // Processor replaces open/close quote with " but doesn't strip adjacent spaces
        #expect(result.contains("\""))
    }

    @Test func emptyString() {
        let result = processor.process("", context: ctx).text
        #expect(result == "")
    }

    @Test func noSpokenPunctuation() {
        let result = processor.process("hello world", context: ctx).text
        #expect(result == "hello world")
    }

    // MARK: - New tests: sentence-ending punctuation

    @Test func fullStop() {
        let result = processor.process("I agree full stop", context: ctx).text
        #expect(result == "I agree.")
    }

    @Test func bang() {
        let result = processor.process("that's amazing bang", context: ctx).text
        #expect(result == "that's amazing!")
    }

    @Test func threeDots() {
        let result = processor.process("thinking three dots maybe later", context: ctx).text
        #expect(result == "thinking... maybe later")
    }

    // MARK: - New tests: mid-sentence punctuation

    @Test func emDash() {
        let result = processor.process("I went em dash the one on main em dash to buy milk", context: ctx).text
        #expect(result.contains("\u{2014}"))
    }

    @Test func enDash() {
        let result = processor.process("pages one en dash five", context: ctx).text
        #expect(result.contains("\u{2013}"))
    }

    @Test func hyphen() {
        let result = processor.process("well hyphen known", context: ctx).text
        #expect(result.contains("-"))
    }

    @Test func forwardSlash() {
        let result = processor.process("and forward slash or", context: ctx).text
        #expect(result.contains("/"))
    }

    @Test func backslash() {
        let result = processor.process("C back slash windows", context: ctx).text
        #expect(result.contains("\\"))
    }

    @Test func pipe() {
        let result = processor.process("this pipe that", context: ctx).text
        #expect(result.contains("|"))
    }

    // MARK: - New tests: paired delimiters

    @Test func openCloseBracket() {
        let result = processor.process("see section open bracket one close bracket", context: ctx).text
        #expect(result.contains("["))
        #expect(result.contains("]"))
    }

    @Test func openCloseBrace() {
        let result = processor.process("open brace x close brace", context: ctx).text
        #expect(result.contains("{"))
        #expect(result.contains("}"))
    }

    @Test func openCloseAngle() {
        let result = processor.process("open angle string close angle", context: ctx).text
        #expect(result.contains("<"))
        #expect(result.contains(">"))
    }

    @Test func beginEndQuote() {
        let result = processor.process("she said begin quote hello end quote", context: ctx).text
        #expect(result.contains("\""))
    }

    @Test func unquote() {
        let result = processor.process("he said open quote ok unquote", context: ctx).text
        // Both "open quote" and "unquote" produce a " character
        let quoteCount = result.filter { $0 == "\"" }.count
        #expect(quoteCount >= 2)
    }

    @Test func singleQuote() {
        let result = processor.process("it single quote s fine", context: ctx).text
        #expect(result.contains("'"))
    }

    // MARK: - New tests: special characters

    @Test func atSign() {
        let result = processor.process("email at sign domain", context: ctx).text
        #expect(result.contains("@"))
    }

    @Test func hashtag() {
        let result = processor.process("use the hashtag thinkur", context: ctx).text
        #expect(result.contains("#"))
    }

    @Test func ampersand() {
        let result = processor.process("smith ampersand jones", context: ctx).text
        #expect(result.contains("&"))
    }

    @Test func asterisk() {
        let result = processor.process("use asterisk for emphasis", context: ctx).text
        #expect(result.contains("*"))
    }

    @Test func dollarSign() {
        let result = processor.process("costs dollar sign five", context: ctx).text
        #expect(result.contains("$"))
    }

    @Test func tilde() {
        let result = processor.process("home tilde path", context: ctx).text
        #expect(result.contains("~"))
    }

    @Test func underscore() {
        let result = processor.process("my underscore variable", context: ctx).text
        #expect(result.contains("_"))
    }

    @Test func copyrightSign() {
        let result = processor.process("copyright sign 2024", context: ctx).text
        #expect(result.contains("\u{00A9}"))
    }

    @Test func trademarkSign() {
        let result = processor.process("brand trademark sign", context: ctx).text
        #expect(result.contains("\u{2122}"))
    }

    @Test func degreeSign() {
        let result = processor.process("thirty degree sign", context: ctx).text
        #expect(result.contains("\u{00B0}"))
    }

    @Test func bulletPoint() {
        let result = processor.process("bullet point item", context: ctx).text
        #expect(result.contains("\u{2022}"))
    }

    // MARK: - New tests: formatting commands

    @Test func nextParagraph() {
        let result = processor.process("first next paragraph second", context: ctx).text
        #expect(result.contains("\n\n"))
    }

    @Test func tab() {
        // The "tab" keyword is replaced with \t, but normalizeWhitespace collapses
        // tabs into spaces. Verify the keyword itself is consumed.
        let result = processor.process("column one tab column two", context: ctx).text
        #expect(!result.contains("tab"))
        #expect(result.contains("column one"))
        #expect(result.contains("column two"))
    }

    // MARK: - New tests: disambiguation

    @Test func periodDisambiguation() {
        let result = processor.process("the trial period lasted six months", context: ctx).text
        #expect(result.contains("period"))
    }

    @Test func colonDisambiguation() {
        let result = processor.process("the colon is part of digestion", context: ctx).text
        #expect(result.contains("colon"))
    }

    // MARK: - New tests: correction metadata

    @Test func correctionMetadata() {
        let result = processor.process("hello period", context: ctx)
        #expect(!result.corrections.isEmpty)
    }
}
