import Testing
@testable import thinkur

@Suite("DateTimeFormatter")
struct DateTimeFormatterTests {
    @Test func tryParseDateWithOrdinalDay() {
        let words = ["January", "first"]
        let result = DateTimeFormatter.tryParseDate(
            words: words, monthIndex: 0, month: (name: "January", num: 1)
        )
        #expect(result?.formatted == "January 1st")
        #expect(result?.endIndex == 2)
    }

    @Test func tryParseDateWithCardinalDay() {
        let words = ["March", "five"]
        let result = DateTimeFormatter.tryParseDate(
            words: words, monthIndex: 0, month: (name: "March", num: 3)
        )
        #expect(result?.formatted == "March 5")
        #expect(result?.endIndex == 2)
    }

    @Test func tryParseQuarterPast() {
        let words = ["quarter", "past", "three"]
        let result = DateTimeFormatter.tryParseQuarterOrHalfPast(words: words, index: 0)
        #expect(result?.formatted == "3:15")
        #expect(result?.endIndex == 3)
    }

    @Test func tryParseHalfPast() {
        let words = ["half", "past", "six"]
        let result = DateTimeFormatter.tryParseQuarterOrHalfPast(words: words, index: 0)
        #expect(result?.formatted == "6:30")
        #expect(result?.endIndex == 3)
    }

    @Test func ordinalToNumberConvertsFirst() {
        #expect(DateTimeFormatter.ordinalToNumber("first") == 1)
    }

    @Test func ordinalToNumberConvertsTwentieth() {
        #expect(DateTimeFormatter.ordinalToNumber("twentieth") == 20)
    }

    @Test func ordinalToNumberReturnsZeroForUnknown() {
        #expect(DateTimeFormatter.ordinalToNumber("banana") == 0)
    }
}
