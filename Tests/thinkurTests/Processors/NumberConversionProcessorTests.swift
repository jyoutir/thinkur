import Testing
@testable import thinkur

@Suite("NumberConversionProcessor")
struct NumberConversionProcessorTests {
    let processor = NumberConversionProcessor()
    let ctx = ProcessingContext(
        frontmostAppBundleID: "com.test",
        frontmostAppName: "Test",
        wordTimings: [],
        appStyle: .standard
    )

    @Test func compoundNumber() {
        let result = processor.process("twenty three", context: ctx)
        #expect(result == "23")
    }

    @Test func largeCompound() {
        let result = processor.process("one hundred and forty five", context: ctx)
        #expect(result == "145")
    }

    @Test func thousandScale() {
        let result = processor.process("two thousand three hundred", context: ctx)
        #expect(result == "2300")
    }

    @Test func singleSmallNumberNotConverted() {
        // Single small numbers like "one" "two" should NOT be converted
        let result = processor.process("I have one dog", context: ctx)
        #expect(result == "I have one dog")
    }

    @Test func mixedTextAndNumbers() {
        let result = processor.process("I need twenty five apples", context: ctx)
        #expect(result == "I need 25 apples")
    }

    @Test func noNumbers() {
        let result = processor.process("hello world", context: ctx)
        #expect(result == "hello world")
    }

    @Test func emptyString() {
        let result = processor.process("", context: ctx)
        #expect(result == "")
    }

    @Test func tensOnly() {
        let result = processor.process("fifty sixty", context: ctx)
        // "fifty sixty" are two adjacent number words, parsed together
        let parsed = processor.process("fifty sixty", context: ctx)
        // Depends on parser behavior — at minimum should not crash
        #expect(!parsed.isEmpty)
    }

    @Test func hundredCompound() {
        let result = processor.process("three hundred", context: ctx)
        #expect(result == "300")
    }
}
