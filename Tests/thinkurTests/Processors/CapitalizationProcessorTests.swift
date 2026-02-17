import Testing
@testable import thinkur

@Suite("CapitalizationProcessor")
struct CapitalizationProcessorTests {
    let processor = CapitalizationProcessor()
    let ctx = ProcessingContext(
        frontmostAppBundleID: "com.test",
        frontmostAppName: "Test",
        wordTimings: [],
        appStyle: .standard
    )

    @Test func capitalizesFirstWord() {
        let result = processor.process("hello world", context: ctx).text
        #expect(result.hasPrefix("H"))
    }

    @Test func capitalizesAfterPeriod() {
        let result = processor.process("hello. world", context: ctx).text
        #expect(result.contains(". W"))
    }

    @Test func capitalizesAfterExclamation() {
        let result = processor.process("wow! great", context: ctx).text
        #expect(result.contains("! G"))
    }

    @Test func capitalizesAfterQuestion() {
        let result = processor.process("really? yes", context: ctx).text
        #expect(result.contains("? Y"))
    }

    @Test func capitalizesStandaloneI() {
        let result = processor.process("i think i am right", context: ctx).text
        #expect(result.contains("I think") || result.contains("I Think"))
        #expect(result.contains("I am") || result.contains("I Am"))
    }

    @Test func emptyString() {
        let result = processor.process("", context: ctx).text
        #expect(result == "")
    }

    @Test func alreadyCapitalized() {
        let result = processor.process("Hello World", context: ctx).text
        #expect(result.hasPrefix("Hello"))
    }

    @Test func capitalizesAfterNewline() {
        let result = processor.process("hello\nworld", context: ctx).text
        #expect(result.contains("\nW"))
    }
}
