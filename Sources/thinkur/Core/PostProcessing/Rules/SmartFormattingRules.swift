import Foundation

enum SmartFormattingRules {
    // MARK: - Number Word Maps

    static let ones: [String: Int] = [
        "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4,
        "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9,
        "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13,
        "fourteen": 14, "fifteen": 15, "sixteen": 16, "seventeen": 17,
        "eighteen": 18, "nineteen": 19,
    ]

    static let tens: [String: Int] = [
        "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50,
        "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90,
    ]

    static let magnitudes: [String: Int] = [
        "hundred": 100,
        "thousand": 1_000,
        "million": 1_000_000,
        "billion": 1_000_000_000,
        "trillion": 1_000_000_000_000,
    ]

    static let allNumberWords: Set<String> = {
        var words = Set(ones.keys)
        words.formUnion(tens.keys)
        words.formUnion(magnitudes.keys)
        words.insert("and")
        return words
    }()

    // MARK: - Ordinal Maps

    static let ordinalOnes: [String: String] = [
        "first": "1st", "second": "2nd", "third": "3rd", "fourth": "4th",
        "fifth": "5th", "sixth": "6th", "seventh": "7th", "eighth": "8th",
        "ninth": "9th", "tenth": "10th", "eleventh": "11th", "twelfth": "12th",
        "thirteenth": "13th", "fourteenth": "14th", "fifteenth": "15th",
        "sixteenth": "16th", "seventeenth": "17th", "eighteenth": "18th",
        "nineteenth": "19th",
    ]

    static let ordinalTens: [String: String] = [
        "twentieth": "20th", "thirtieth": "30th", "fortieth": "40th",
        "fiftieth": "50th", "sixtieth": "60th", "seventieth": "70th",
        "eightieth": "80th", "ninetieth": "90th",
    ]

    // MARK: - Fraction Denominators

    static let fractionWords: [String: String] = [
        "half": "2", "halves": "2",
        "third": "3", "thirds": "3",
        "quarter": "4", "quarters": "4",
        "fourth": "4", "fourths": "4",
        "fifth": "5", "fifths": "5",
        "sixth": "6", "sixths": "6",
        "seventh": "7", "sevenths": "7",
        "eighth": "8", "eighths": "8",
        "ninth": "9", "ninths": "9",
        "tenth": "10", "tenths": "10",
        "hundredth": "100", "hundredths": "100",
        "thousandth": "1000", "thousandths": "1000",
    ]

    // MARK: - Month Names

    static let months: [String: (number: Int, name: String)] = [
        "january": (1, "January"), "jan": (1, "January"),
        "february": (2, "February"), "feb": (2, "February"),
        "march": (3, "March"), "mar": (3, "March"),
        "april": (4, "April"), "apr": (4, "April"),
        "may": (5, "May"),
        "june": (6, "June"), "jun": (6, "June"),
        "july": (7, "July"), "jul": (7, "July"),
        "august": (8, "August"), "aug": (8, "August"),
        "september": (9, "September"), "sept": (9, "September"), "sep": (9, "September"),
        "october": (10, "October"), "oct": (10, "October"),
        "november": (11, "November"), "nov": (11, "November"),
        "december": (12, "December"), "dec": (12, "December"),
    ]

    // MARK: - Currency

    static let currencyWords: [String: (symbol: String, placement: CurrencyPlacement)] = [
        "dollar": (.init("$"), .prefix), "dollars": (.init("$"), .prefix),
        "buck": (.init("$"), .prefix), "bucks": (.init("$"), .prefix),
        "cent": (.init("\u{00A2}"), .suffix), "cents": (.init("\u{00A2}"), .suffix),
        "euro": (.init("\u{20AC}"), .prefix), "euros": (.init("\u{20AC}"), .prefix),
        "pound": (.init("\u{00A3}"), .prefix), "pounds": (.init("\u{00A3}"), .prefix),
        "quid": (.init("\u{00A3}"), .prefix),
        "yen": (.init("\u{00A5}"), .prefix),
        "rupee": (.init("\u{20B9}"), .prefix), "rupees": (.init("\u{20B9}"), .prefix),
    ]

    enum CurrencyPlacement {
        case prefix  // $50
        case suffix  // 25¢
    }

    // MARK: - Unit Abbreviations

    static let unitAbbreviations: [String: String] = [
        // Length
        "millimeter": "mm", "millimeters": "mm",
        "centimeter": "cm", "centimeters": "cm",
        "meter": "m", "meters": "m",
        "kilometer": "km", "kilometers": "km",
        "inch": "in", "inches": "in",
        "yard": "yd", "yards": "yd",
        "mile": "mi", "miles": "mi",
        // Weight
        "milligram": "mg", "milligrams": "mg",
        "gram": "g", "grams": "g",
        "kilogram": "kg", "kilograms": "kg",
        "ounce": "oz", "ounces": "oz",
        "ton": "t", "tons": "t",
        // Volume
        "milliliter": "mL", "milliliters": "mL",
        "liter": "L", "liters": "L",
        "gallon": "gal", "gallons": "gal",
        "tablespoon": "tbsp", "tablespoons": "tbsp",
        "teaspoon": "tsp", "teaspoons": "tsp",
        // Temperature
        "fahrenheit": "F", "celsius": "C", "kelvin": "K",
        // Speed
        "miles per hour": "mph",
        "kilometers per hour": "km/h",
        // Digital
        "byte": "B", "bytes": "B",
        "kilobyte": "KB", "kilobytes": "KB",
        "megabyte": "MB", "megabytes": "MB",
        "gigabyte": "GB", "gigabytes": "GB",
        "terabyte": "TB", "terabytes": "TB",
        "hertz": "Hz",
        "kilohertz": "kHz",
        "megahertz": "MHz",
        "gigahertz": "GHz",
        // Time (measurement context)
        "millisecond": "ms", "milliseconds": "ms",
        // Misc
        "pixel": "px", "pixels": "px",
        "watt": "W", "watts": "W",
        "kilowatt": "kW", "kilowatts": "kW",
        "volt": "V", "volts": "V",
        "ampere": "A", "amp": "A", "amps": "A",
    ]

    // MARK: - Large Number Words

    static let largeNumberWords: [String: Int] = [
        "dozen": 12,
        "hundred": 100,
        "thousand": 1_000,
        "million": 1_000_000,
    ]

    // MARK: - Ordinal Disambiguation

    static let ordinalKeepPatterns: [String] = [
        // Adverb at sentence start
        #"(?i)(?:^|(?<=[.!?\\n]\s*))first\b"#,
        // Idioms
        #"(?i)\bfirst\s+(of\s+all|and\s+foremost|things\s+first|come\s+first|off|up)\b"#,
        #"(?i)\bat\s+first\b"#,
        // "first/second/third time" — natural phrasing
        #"(?i)\b(first|second|third)\s+(time|place|best|worst|half|floor|base|round|quarter)\b"#,
        // "second" as time unit
        #"(?i)\b(wait|just)\s+a\s+second\b"#,
        // Compound noun uses
        #"(?i)\bsecond\s+(thought|thoughts|guess|nature|hand|chance|opinion)\b"#,
        #"(?i)\bthird\s+(party|person|world|eye|wheel|degree)\b"#,
        // "number one/two" — idiomatic
        #"(?i)\bnumber\s+(one|two|three|four|five|six|seven|eight|nine|ten)\b"#,
        // "first/second paragraph" — document structure, keep as words
        #"(?i)\b(first|second|third|fourth|fifth|sixth)\s+paragraph\b"#,
    ]

    // MARK: - "may" Disambiguation

    static let mayVerbPatterns: [String] = [
        #"(?i)\b(i|you|we|they|he|she|it)\s+may\b"#,
        #"(?i)\bmay\s+(be|have|has|had|go|come|want|need|get|take|see|do|make|know|think|say|give|find|use|tell)\b"#,
    ]

    static let mayMonthPatterns: [String] = [
        #"(?i)\bmay\s+(first|second|third|fourth|fifth|\d{1,2}(st|nd|rd|th)?)\b"#,
        #"(?i)\bin\s+may\b"#,
    ]

    // MARK: - "point" Disambiguation

    static let decimalPointPattern =
        #"(?i)\b(zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|hundred|thousand|million|billion|\d+)\s+point\s+(zero|one|two|three|four|five|six|seven|eight|nine)\b"#

    // MARK: - "pounds" Disambiguation (weight vs currency)

    static let poundsWeightPatterns: [String] = [
        #"(?i)\b(weigh|weighs|weighing|weight|heavy|heavier|heaviest|light|lighter|lightest)\b.*\bpounds?\b"#,
        #"(?i)\bpounds?\s+(per|of\s+(force|pressure|thrust))\b"#,
    ]

    // MARK: - Processing Priority Order

    static let processingOrder: [String] = [
        "phone_number",
        "date",
        "time",
        "currency",
        "percentage",
        "unit",
        "ordinal",
        "fraction",
        "decimal",
        "cardinal",
    ]
}
