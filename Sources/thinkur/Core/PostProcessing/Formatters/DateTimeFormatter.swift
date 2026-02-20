import Foundation

/// Handles date and time formatting for SmartFormattingProcessor.
/// Converts spoken dates ("January fifteenth twenty twenty four") and times
/// ("half past three") into structured formats.
struct DateTimeFormatter {
    /// Try to parse a date starting from monthIndex.
    /// Returns (formatted string, end index) if successful.
    static func tryParseDate(
        words: [String],
        monthIndex: Int,
        month: (name: String, num: Int)
    ) -> (formatted: String, endIndex: Int)? {
        guard monthIndex + 1 < words.count else { return nil }

        let dayWord = words[monthIndex + 1].lowercased()

        // Try ordinal first ("first", "second", etc.)
        if let dayNum = SmartFormattingRules.ordinalOnes[dayWord] ?? SmartFormattingRules.ordinalTens[dayWord] {
            // Check for year
            if monthIndex + 2 < words.count {
                if let year = parseYearWords(words, from: monthIndex + 2) {
                    return ("\(month.name) \(dayNum), \(year.formatted)", monthIndex + year.endIndex)
                }
            }
            return ("\(month.name) \(dayNum)", monthIndex + 2)
        }

        // Try cardinal ("one", "two", ..., "thirty one")
        if let dayNum = SmartFormattingRules.ones[dayWord] {
            if monthIndex + 2 < words.count {
                if let year = parseYearWords(words, from: monthIndex + 2) {
                    return ("\(month.name) \(dayNum), \(year.formatted)", monthIndex + year.endIndex)
                }
            }
            return ("\(month.name) \(dayNum)", monthIndex + 2)
        }

        // Try teens ("twenty", "thirty") + ones ("one", "two")
        if let tens = SmartFormattingRules.tens[dayWord], tens >= 20, monthIndex + 2 < words.count {
            let onesWord = words[monthIndex + 2].lowercased()
            if let ones = SmartFormattingRules.ones[onesWord] {
                let dayNum = tens + ones
                if monthIndex + 3 < words.count {
                    if let year = parseYearWords(words, from: monthIndex + 3) {
                        return ("\(month.name) \(dayNum), \(year.formatted)", monthIndex + year.endIndex)
                    }
                }
                return ("\(month.name) \(dayNum)", monthIndex + 3)
            }
        }

        return nil
    }

    /// Parse year like "twenty twenty four" → 2024
    private static func parseYearWords(_ words: [String], from: Int) -> (formatted: String, endIndex: Int)? {
        guard from < words.count else { return nil }
        let word1 = words[from].lowercased()

        // "two thousand" + optional ones
        if word1 == "two" && from + 1 < words.count && words[from + 1].lowercased() == "thousand" {
            if from + 2 < words.count {
                let next = words[from + 2].lowercased()
                if let ones = SmartFormattingRules.ones[next] {
                    return ("\(2000 + ones)", from + 3)
                } else if let tens = SmartFormattingRules.tens[next] {
                    if from + 3 < words.count, let ones = SmartFormattingRules.ones[words[from + 3].lowercased()] {
                        return ("\(2000 + tens + ones)", from + 4)
                    }
                    return ("\(2000 + tens)", from + 3)
                }
            }
            return ("2000", from + 2)
        }

        // "twenty twenty four" style
        if let tens1 = SmartFormattingRules.tens[word1], tens1 >= 10, from + 1 < words.count {
            let word2 = words[from + 1].lowercased()
            if let tens2 = SmartFormattingRules.tens[word2], tens2 >= 10 {
                if from + 2 < words.count, let ones = SmartFormattingRules.ones[words[from + 2].lowercased()] {
                    let year = tens1 * 100 + tens2 + ones
                    return ("\(year)", from + 3)
                }
                let year = tens1 * 100 + tens2
                return ("\(year)", from + 2)
            }
        }

        return nil
    }

    /// Try to parse "quarter past N" or "half past N"
    static func tryParseQuarterOrHalfPast(
        words: [String],
        index: Int
    ) -> (formatted: String, endIndex: Int)? {
        guard index + 2 < words.count else { return nil }
        let word = words[index].lowercased()
        guard words[index + 1].lowercased() == "past" else { return nil }

        let hourWord = words[index + 2].lowercased()
        guard let hour = SmartFormattingRules.ones[hourWord], hour >= 1, hour <= 12 else {
            return nil
        }

        let minutes: String
        if word == "quarter" {
            minutes = "15"
        } else if word == "half" {
            minutes = "30"
        } else {
            return nil
        }

        return ("\(hour):\(minutes)", index + 3)
    }

    /// Convert ordinal word to number ("first" → 1, "twenty first" → 21)
    static func ordinalToNumber(_ word: String) -> Int {
        let lower = word.lowercased()

        // Extract numeric value from ordinal string (e.g., "1st" → 1)
        if let ordStr = SmartFormattingRules.ordinalOnes[lower],
           let num = Int(ordStr.replacingOccurrences(of: #"(st|nd|rd|th)"#, with: "", options: .regularExpression)) {
            return num
        }
        if let ordStr = SmartFormattingRules.ordinalTens[lower],
           let num = Int(ordStr.replacingOccurrences(of: #"(st|nd|rd|th)"#, with: "", options: .regularExpression)) {
            return num
        }

        // Try compound: "twenty first"
        let parts = lower.split(separator: " ")
        if parts.count == 2 {
            if let tensStr = SmartFormattingRules.ordinalTens[String(parts[0])],
               let onesStr = SmartFormattingRules.ordinalOnes[String(parts[1])],
               let tens = Int(tensStr.replacingOccurrences(of: #"(st|nd|rd|th)"#, with: "", options: .regularExpression)),
               let ones = Int(onesStr.replacingOccurrences(of: #"(st|nd|rd|th)"#, with: "", options: .regularExpression)) {
                return tens + ones
            }
        }
        return 0
    }
}
