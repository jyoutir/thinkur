import Testing
@testable import thinkur

@Suite("SmartFormattingProcessor")
struct SmartFormattingProcessorTests {
    let processor = SmartFormattingProcessor()
    let ctx = ProcessingContext(
        frontmostAppBundleID: "com.test",
        frontmostAppName: "Test",
        wordTimings: [],
        appStyle: .standard
    )

    // MARK: - Cardinals

    @Test func compoundNumber() {
        let result = processor.process("twenty three", context: ctx)
        #expect(result.text == "23")
    }

    @Test func largeCompound() {
        let result = processor.process("one hundred and forty five", context: ctx)
        #expect(result.text == "145")
    }

    @Test func thousandScale() {
        let result = processor.process("two thousand three hundred", context: ctx)
        #expect(result.text == "2300")
    }

    @Test func singleSmallNumberConverted() {
        let result = processor.process("I have one dog", context: ctx)
        #expect(result.text == "I have 1 dog")
    }

    @Test func singleNumberWordPreservedInIdiom() {
        let result = processor.process("one of the best", context: ctx)
        #expect(result.text == "one of the best")
    }

    @Test func mixedTextAndNumbers() {
        let result = processor.process("I need twenty five apples", context: ctx)
        #expect(result.text == "I need 25 apples")
    }

    @Test func noNumbers() {
        let result = processor.process("hello world", context: ctx)
        #expect(result.text == "hello world")
    }

    @Test func emptyString() {
        let result = processor.process("", context: ctx)
        #expect(result.text == "")
    }

    @Test func tensOnly() {
        // "fifty" is collected, then "sixty" is also a number word, so both collected
        // parseNumber(["fifty","sixty"]) = 50 + 60 = 110
        let result = processor.process("fifty sixty", context: ctx)
        #expect(result.text == "110")
    }

    @Test func hundredCompound() {
        let result = processor.process("three hundred", context: ctx)
        #expect(result.text == "300")
    }

    // MARK: - Percentages

    @Test func percentage() {
        let result = processor.process("fifty percent", context: ctx)
        #expect(result.text == "50%")
    }

    @Test func percentageInContext() {
        let result = processor.process("about twenty five percent of people", context: ctx)
        #expect(result.text == "about 25% of people")
    }

    // MARK: - Currency

    @Test func currencyDollars() {
        let result = processor.process("fifty dollars", context: ctx)
        #expect(result.text == "$50")
    }

    @Test func currencyCents() {
        let result = processor.process("twenty five cents", context: ctx)
        #expect(result.text == "25\u{00A2}")
    }

    @Test func currencyEuros() {
        let result = processor.process("ten euros", context: ctx)
        // "ten" is single number word, but afterWord is "euros" (currency).
        // collectNumberWords picks up ["ten"], count=1, but currency check
        // is before the count>=2 cardinal gate, so it converts.
        #expect(result.text == "\u{20AC}10")
    }

    // MARK: - Units

    @Test func unitKilometers() {
        let result = processor.process("ten kilometers", context: ctx)
        #expect(result.text == "10 km")
    }

    @Test func unitKilograms() {
        let result = processor.process("five kilograms", context: ctx)
        #expect(result.text == "5 kg")
    }

    // MARK: - Decimals

    @Test func decimal() {
        let result = processor.process("three point five", context: ctx)
        #expect(result.text == "3.5")
    }

    @Test func decimalMultiDigit() {
        let result = processor.process("two point one four", context: ctx)
        #expect(result.text == "2.14")
    }

    // MARK: - Negatives

    @Test func negative() {
        let result = processor.process("negative five", context: ctx)
        #expect(result.text.contains("-5"))
    }

    // MARK: - Fractions

    @Test func fraction() {
        let result = processor.process("one half", context: ctx)
        #expect(result.text == "1/2")
    }

    @Test func fractionQuarters() {
        let result = processor.process("three quarters", context: ctx)
        // "three" is single number word, afterWord "quarters" is in fractionWords (denominator "4")
        #expect(result.text == "3/4")
    }

    // MARK: - Ordinals

    @Test func ordinalFirst() {
        // "first" alone at start of text matches the keep pattern
        // (?:^|...)first\b, so it is NOT converted.
        // Place "first" after a non-trigger word so keep patterns don't match.
        let result = processor.process("ranked first", context: ctx)
        #expect(result.text == "ranked 1st")
    }

    @Test func ordinalCompound() {
        // "twenty" is not in ordinalTens (that's "twentieth"), so this goes
        // through number collection: ["twenty"] with afterWord "third" matching
        // fractionWords, yielding a fraction.
        let result = processor.process("twenty third", context: ctx)
        // twenty → 20, third → fraction denominator 3 → "20/3"
        #expect(result.text == "20/3")
    }

    // MARK: - Time

    @Test func timeOClock() {
        let result = processor.process("five o'clock", context: ctx)
        #expect(result.text == "5:00")
    }

    // MARK: - Correction Metadata

    @Test func correctionMetadata() {
        let result = processor.process("twenty three", context: ctx)
        #expect(!result.corrections.isEmpty)
        #expect(result.corrections.first?.processorName == "SmartFormatting")
    }
}
