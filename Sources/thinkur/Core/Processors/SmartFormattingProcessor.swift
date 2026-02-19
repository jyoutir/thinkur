import Foundation

struct SmartFormattingProcessor: TextProcessor {
    let name = "SmartFormatting"

    func process(_ text: String, context: ProcessingContext) -> ProcessorResult {
        guard !text.isEmpty else { return ProcessorResult(text: text) }

        let words = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        var result: [String] = []
        var corrections: [CorrectionEntry] = []
        var i = 0

        while i < words.count {
            let lower = words[i].lowercased()

            // 0. Date: "month day year" patterns
            if let month = SmartFormattingRules.months[lower] {
                if let (formatted, endIdx) = tryParseDate(words: words, monthIndex: i, month: month) {
                    let original = words[i..<endIdx].joined(separator: " ")
                    corrections.append(CorrectionEntry(
                        processorName: name, ruleName: "date",
                        originalFragment: original, replacement: formatted, confidence: 0.9
                    ))
                    result.append(formatted)
                    i = endIdx
                    continue
                }
            }

            // 0b. Date: "the Nth of Month" pattern
            if lower == "the" && i + 3 < words.count {
                let ordWord = words[i + 1].lowercased()
                if (SmartFormattingRules.ordinalOnes[ordWord] != nil || SmartFormattingRules.ordinalTens[ordWord] != nil) &&
                   words[i + 2].lowercased() == "of" {
                    let monthWord = words[i + 3].lowercased()
                    if let month = SmartFormattingRules.months[monthWord] {
                        let dayNum = ordinalToNumber(ordWord)
                        let formatted = "\(month.name) \(dayNum)"
                        let original = words[i..<(i + 4)].joined(separator: " ")
                        corrections.append(CorrectionEntry(
                            processorName: name, ruleName: "date",
                            originalFragment: original, replacement: formatted, confidence: 0.9
                        ))
                        result.append(formatted)
                        i += 4
                        continue
                    }
                }
            }

            // 0c. Time: "quarter past N", "half past N"
            if lower == "quarter" && i + 2 < words.count && words[i + 1].lowercased() == "past" {
                let hourWord = words[i + 2].lowercased()
                if let hour = SmartFormattingRules.ones[hourWord], hour >= 1, hour <= 12 {
                    let formatted = "\(hour):15"
                    let original = words[i...(i + 2)].joined(separator: " ")
                    corrections.append(CorrectionEntry(
                        processorName: name, ruleName: "time",
                        originalFragment: original, replacement: formatted, confidence: 0.9
                    ))
                    result.append(formatted)
                    i += 3
                    continue
                }
            }
            if lower == "half" && i + 2 < words.count && words[i + 1].lowercased() == "past" {
                let hourWord = words[i + 2].lowercased()
                if let hour = SmartFormattingRules.ones[hourWord], hour >= 1, hour <= 12 {
                    let formatted = "\(hour):30"
                    let original = words[i...(i + 2)].joined(separator: " ")
                    corrections.append(CorrectionEntry(
                        processorName: name, ruleName: "time",
                        originalFragment: original, replacement: formatted, confidence: 0.9
                    ))
                    result.append(formatted)
                    i += 3
                    continue
                }
            }

            // 0d. "area code NNN NNN NNNN" phone numbers
            if lower == "area" && i + 1 < words.count && words[i + 1].lowercased() == "code" {
                if let (formatted, endIdx) = tryParsePhoneWithAreaCode(words: words, from: i + 2) {
                    let original = words[i..<endIdx].joined(separator: " ")
                    corrections.append(CorrectionEntry(
                        processorName: name, ruleName: "phone",
                        originalFragment: original, replacement: formatted, confidence: 0.9
                    ))
                    result.append(formatted)
                    i = endIdx
                    continue
                }
            }

            // 1. Check for "negative" / "minus" prefix
            if (lower == "negative" || lower == "minus") && i + 1 < words.count {
                let nextLower = words[i + 1].lowercased()
                if SmartFormattingRules.ones[nextLower] != nil || SmartFormattingRules.tens[nextLower] != nil {
                    let (numberWords, endIndex) = collectNumberWords(words, from: i + 1)
                    let value = parseNumber(numberWords)
                    let original = words[i..<endIndex].joined(separator: " ")
                    let formatted = "-\(value)"
                    corrections.append(CorrectionEntry(
                        processorName: name, ruleName: "negative",
                        originalFragment: original, replacement: formatted, confidence: 0.9
                    ))
                    result.append(formatted)
                    i = endIndex
                    continue
                }
            }

            // 2. Check for ordinal words (standalone)
            if let ordinal = SmartFormattingRules.ordinalOnes[lower] {
                if !shouldKeepOrdinal(lower, words: words, index: i) {
                    let original = words[i]
                    corrections.append(CorrectionEntry(
                        processorName: name, ruleName: "ordinal",
                        originalFragment: original, replacement: ordinal, confidence: 0.8
                    ))
                    result.append(ordinal)
                    i += 1
                    continue
                }
            }
            if let ordinal = SmartFormattingRules.ordinalTens[lower] {
                if !shouldKeepOrdinal(lower, words: words, index: i) {
                    // Check for compound ordinal: "twenty third" → "23rd"
                    if i + 1 < words.count,
                       let onesOrdinal = SmartFormattingRules.ordinalOnes[words[i + 1].lowercased()] {
                        let tensValue = Int(ordinal.dropLast(2)) ?? 0
                        let onesValue = Int(onesOrdinal.filter(\.isNumber)) ?? 0
                        let suffix = ordinalSuffix(for: onesValue)
                        let compound = "\(tensValue + onesValue)\(suffix)"
                        let original = "\(words[i]) \(words[i + 1])"
                        corrections.append(CorrectionEntry(
                            processorName: name, ruleName: "ordinal",
                            originalFragment: original, replacement: compound, confidence: 0.85
                        ))
                        result.append(compound)
                        i += 2
                        continue
                    }
                    let original = words[i]
                    corrections.append(CorrectionEntry(
                        processorName: name, ruleName: "ordinal",
                        originalFragment: original, replacement: ordinal, confidence: 0.8
                    ))
                    result.append(ordinal)
                    i += 1
                    continue
                }
            }

            // 3. Check for number words
            if SmartFormattingRules.ones[lower] != nil || SmartFormattingRules.tens[lower] != nil {
                let (numberWords, endIndex) = collectNumberWords(words, from: i)
                let afterWord = endIndex < words.count ? words[endIndex].lowercased() : ""

                // 3a. Percentage: "fifty percent" → "50%"
                if afterWord == "percent" || afterWord == "percentage" {
                    let value = parseNumber(numberWords)
                    let original = words[i...endIndex].joined(separator: " ")
                    let formatted = "\(value)%"
                    corrections.append(CorrectionEntry(
                        processorName: name, ruleName: "percentage",
                        originalFragment: original, replacement: formatted, confidence: 0.95
                    ))
                    result.append(formatted)
                    i = endIndex + 1
                    continue
                }

                // 3aa. Currency with "and cents": "twenty five dollars and fifty cents" → "$25.50"
                if let currency = SmartFormattingRules.currencyWords[afterWord],
                   currency.placement == .prefix,
                   (afterWord == "dollar" || afterWord == "dollars") {
                    // Check for "and N cents" after
                    let value = parseNumber(numberWords)
                    var consumeEnd = endIndex + 1
                    var centsValue: Int? = nil

                    if consumeEnd < words.count && words[consumeEnd].lowercased() == "and" {
                        let afterAnd = consumeEnd + 1
                        if afterAnd < words.count {
                            let (centsWords, centsEnd) = collectNumberWords(words, from: afterAnd)
                            if !centsWords.isEmpty && centsEnd < words.count {
                                let centsAfter = words[centsEnd].lowercased()
                                if centsAfter == "cents" || centsAfter == "cent" {
                                    centsValue = parseNumber(centsWords)
                                    consumeEnd = centsEnd + 1
                                }
                            }
                        }
                    }

                    let original = words[i..<consumeEnd].joined(separator: " ")
                    let formatted: String
                    if let cents = centsValue {
                        formatted = "\(currency.symbol)\(formatWithCommas(value)).\(String(format: "%02d", cents))"
                    } else {
                        formatted = "\(currency.symbol)\(formatWithCommas(value))"
                    }
                    corrections.append(CorrectionEntry(
                        processorName: name, ruleName: "currency",
                        originalFragment: original, replacement: formatted, confidence: 0.9
                    ))
                    result.append(formatted)
                    i = consumeEnd
                    continue
                }

                // 3b. Currency: "fifty dollars" → "$50", "fifty bucks" → "$50"
                if let currency = SmartFormattingRules.currencyWords[afterWord] {
                    // Disambiguate "pounds" as weight
                    if (afterWord == "pound" || afterWord == "pounds") &&
                       DisambiguatingMatcher.anyPatternMatches(SmartFormattingRules.poundsWeightPatterns, in: text) {
                        // Fall through to cardinal
                    } else {
                        let value = parseNumber(numberWords)
                        let original = words[i...endIndex].joined(separator: " ")
                        let formatted: String
                        if currency.placement == .prefix {
                            formatted = "\(currency.symbol)\(formatWithCommas(value))"
                        } else {
                            formatted = "\(formatWithCommas(value))\(currency.symbol)"
                        }
                        corrections.append(CorrectionEntry(
                            processorName: name, ruleName: "currency",
                            originalFragment: original, replacement: formatted, confidence: 0.9
                        ))
                        result.append(formatted)
                        i = endIndex + 1
                        continue
                    }
                }

                // 3bb. Measurement: "N feet N inches" → N'N"
                if afterWord == "feet" || afterWord == "foot" {
                    let feetValue = parseNumber(numberWords)
                    let consumeEnd = endIndex + 1
                    // Check for inches after
                    if consumeEnd < words.count {
                        let (inchWords, inchEnd) = collectNumberWords(words, from: consumeEnd)
                        if !inchWords.isEmpty && inchEnd < words.count {
                            let inchAfter = words[inchEnd].lowercased()
                            if inchAfter == "inches" || inchAfter == "inch" {
                                let inchValue = parseNumber(inchWords)
                                let original = words[i..<(inchEnd + 1)].joined(separator: " ")
                                let formatted = "\(feetValue)'\(inchValue)\""
                                corrections.append(CorrectionEntry(
                                    processorName: name, ruleName: "measurement",
                                    originalFragment: original, replacement: formatted, confidence: 0.9
                                ))
                                result.append(formatted)
                                i = inchEnd + 1
                                continue
                            }
                        }
                    }
                }

                // 3bc. Temperature: "N degrees fahrenheit/celsius" → N°F/C
                if afterWord == "degrees" {
                    let value = parseNumber(numberWords)
                    let afterDegrees = endIndex + 1 < words.count ? words[endIndex + 1].lowercased() : ""
                    if afterDegrees == "fahrenheit" {
                        let original = words[i...(endIndex + 1)].joined(separator: " ")
                        let formatted = "\(value)\u{00B0}F"
                        corrections.append(CorrectionEntry(
                            processorName: name, ruleName: "measurement",
                            originalFragment: original, replacement: formatted, confidence: 0.9
                        ))
                        result.append(formatted)
                        i = endIndex + 2
                        continue
                    } else if afterDegrees == "celsius" {
                        let original = words[i...(endIndex + 1)].joined(separator: " ")
                        let formatted = "\(value)\u{00B0}C"
                        corrections.append(CorrectionEntry(
                            processorName: name, ruleName: "measurement",
                            originalFragment: original, replacement: formatted, confidence: 0.9
                        ))
                        result.append(formatted)
                        i = endIndex + 2
                        continue
                    }
                }

                // 3bd. Military time: "fourteen hundred hours" → "14:00"
                if afterWord == "hundred" && endIndex + 1 < words.count && words[endIndex + 1].lowercased() == "hours" {
                    let hourValue = parseNumber(numberWords)
                    if hourValue >= 0 && hourValue <= 23 {
                        let original = words[i...(endIndex + 1)].joined(separator: " ")
                        let formatted = "\(hourValue):00"
                        corrections.append(CorrectionEntry(
                            processorName: name, ruleName: "time",
                            originalFragment: original, replacement: formatted, confidence: 0.85
                        ))
                        result.append(formatted)
                        i = endIndex + 2
                        continue
                    }
                }

                // 3c. Unit: "ten kilometers" → "10 km"
                if let unit = SmartFormattingRules.unitAbbreviations[afterWord] {
                    let value = parseNumber(numberWords)
                    let original = words[i...endIndex].joined(separator: " ")
                    let formatted = "\(value) \(unit)"
                    corrections.append(CorrectionEntry(
                        processorName: name, ruleName: "unit",
                        originalFragment: original, replacement: formatted, confidence: 0.85
                    ))
                    result.append(formatted)
                    i = endIndex + 1
                    continue
                }

                // 3d. Decimal: "three point five" → "3.5"
                if afterWord == "point" && endIndex + 1 < words.count {
                    let decimalWord = words[endIndex + 1].lowercased()
                    if let decimalDigit = SmartFormattingRules.ones[decimalWord], decimalDigit <= 9 {
                        // Collect all decimal digits
                        let wholePart = parseNumber(numberWords)
                        var decimalPart = "\(decimalDigit)"
                        var j = endIndex + 2
                        while j < words.count {
                            let dw = words[j].lowercased()
                            if let d = SmartFormattingRules.ones[dw], d <= 9 {
                                decimalPart += "\(d)"
                                j += 1
                            } else {
                                break
                            }
                        }
                        let original = words[i..<j].joined(separator: " ")
                        let formatted = "\(wholePart).\(decimalPart)"

                        // Check for decimal currency: "12.3 million dollars"
                        if j < words.count {
                            let nextW = words[j].lowercased()
                            if let mag = SmartFormattingRules.magnitudes[nextW], mag >= 1000 {
                                if j + 1 < words.count, let curr = SmartFormattingRules.currencyWords[words[j + 1].lowercased()],
                                   curr.placement == .prefix {
                                    let fullOriginal = words[i...(j + 1)].joined(separator: " ")
                                    let decimalFormatted = "\(curr.symbol)\(formatted) \(nextW)"
                                    corrections.append(CorrectionEntry(
                                        processorName: name, ruleName: "currency",
                                        originalFragment: fullOriginal, replacement: decimalFormatted, confidence: 0.9
                                    ))
                                    result.append(decimalFormatted)
                                    i = j + 2
                                    continue
                                }
                            }
                        }

                        corrections.append(CorrectionEntry(
                            processorName: name, ruleName: "decimal",
                            originalFragment: original, replacement: formatted, confidence: 0.9
                        ))
                        result.append(formatted)
                        i = j
                        continue
                    }
                }

                // 3e. Fraction: "one half" / "three quarters" → "1/2" / "3/4"
                if let denominator = SmartFormattingRules.fractionWords[afterWord] {
                    let numerator = parseNumber(numberWords)
                    let original = words[i...endIndex].joined(separator: " ")
                    let formatted = "\(numerator)/\(denominator)"
                    corrections.append(CorrectionEntry(
                        processorName: name, ruleName: "fraction",
                        originalFragment: original, replacement: formatted, confidence: 0.85
                    ))
                    result.append(formatted)
                    i = endIndex + 1
                    continue
                }

                // 3f. Time: "N thirty pm" / "N forty five am" / "N pm" / "N am"
                if let (timeFormatted, timeEndIdx) = tryParseTime(words: words, numberWords: numberWords, numberEndIndex: endIndex) {
                    let original = words[i..<timeEndIdx].joined(separator: " ")
                    corrections.append(CorrectionEntry(
                        processorName: name, ruleName: "time",
                        originalFragment: original, replacement: timeFormatted, confidence: 0.85
                    ))
                    result.append(timeFormatted)
                    i = timeEndIdx
                    continue
                }

                // 3f2. Time: number followed by "o'clock"
                if afterWord == "o'clock" || afterWord == "oclock" {
                    let value = parseNumber(numberWords)
                    if value >= 1 && value <= 12 {
                        let original = words[i...endIndex].joined(separator: " ")
                        let formatted = "\(value):00"
                        corrections.append(CorrectionEntry(
                            processorName: name, ruleName: "time",
                            originalFragment: original, replacement: formatted, confidence: 0.85
                        ))
                        result.append(formatted)
                        i = endIndex + 1
                        continue
                    }
                }

                // 3g. Phone number: sequence of 7+ single digits
                if let (phoneFormatted, phoneEnd) = tryParsePhoneNumber(words: words, from: i) {
                    let original = words[i..<phoneEnd].joined(separator: " ")
                    corrections.append(CorrectionEntry(
                        processorName: name, ruleName: "phone",
                        originalFragment: original, replacement: phoneFormatted, confidence: 0.85
                    ))
                    result.append(phoneFormatted)
                    i = phoneEnd
                    continue
                }

                // 3h. Cardinal: number words → digits
                if numberWords.count >= 2 {
                    let value = parseNumber(numberWords)
                    let original = words[i..<endIndex].joined(separator: " ")
                    corrections.append(CorrectionEntry(
                        processorName: name, ruleName: "cardinal",
                        originalFragment: original, replacement: String(value), confidence: 0.9
                    ))
                    result.append(String(value))
                    i = endIndex
                    continue
                }

                // 3i. Single number word → digit (unless small number before noun, or idiomatic)
                if !shouldKeepNumberWord(lower, words: words, index: i) {
                    let value = parseNumber(numberWords)
                    let original = words[i]
                    corrections.append(CorrectionEntry(
                        processorName: name, ruleName: "cardinal_single",
                        originalFragment: original, replacement: String(value), confidence: 0.8
                    ))
                    result.append(String(value))
                    i = endIndex
                    continue
                }

                result.append(words[i])
                i += 1
            } else {
                result.append(words[i])
                i += 1
            }
        }

        return ProcessorResult(
            text: result.joined(separator: " "),
            corrections: corrections
        )
    }

    // MARK: - Date Parsing

    private func tryParseDate(words: [String], monthIndex: Int, month: (number: Int, name: String)) -> (String, Int)? {
        let i = monthIndex
        guard i + 1 < words.count else { return nil }

        // "January fifteenth" or "January fifteen" (ordinal or cardinal day)
        let dayWord = words[i + 1].lowercased()
        var dayNum: Int?
        var consumeEnd = i + 2

        if let ordinal = SmartFormattingRules.ordinalOnes[dayWord] {
            dayNum = Int(ordinal.filter(\.isNumber))
        } else if let cardinal = SmartFormattingRules.ones[dayWord] {
            dayNum = cardinal
        } else if let cardinal = SmartFormattingRules.tens[dayWord] {
            dayNum = cardinal
        }

        // Try compound day: "twenty fifth"
        if dayNum == nil && SmartFormattingRules.tens[dayWord] != nil {
            if i + 2 < words.count {
                let nextDay = words[i + 2].lowercased()
                if let ordOnes = SmartFormattingRules.ordinalOnes[nextDay] {
                    let tensVal = SmartFormattingRules.tens[dayWord]!
                    let onesVal = Int(ordOnes.filter(\.isNumber)) ?? 0
                    dayNum = tensVal + onesVal
                    consumeEnd = i + 3
                } else if let cardOnes = SmartFormattingRules.ones[nextDay] {
                    dayNum = SmartFormattingRules.tens[dayWord]! + cardOnes
                    consumeEnd = i + 3
                }
            }
        }

        guard let day = dayNum, day >= 1, day <= 31 else { return nil }

        // Check for year: "twenty twenty six" or "two thousand twenty five"
        if consumeEnd < words.count {
            let (yearWords, yearEnd) = collectNumberWords(words, from: consumeEnd)
            if yearWords.count >= 2 {
                let yearValue = parseYearWords(yearWords)
                if yearValue >= 1900 && yearValue <= 2100 {
                    return ("\(month.name) \(day), \(yearValue)", yearEnd)
                }
            }
        }

        // No year — just "January 15"
        return ("\(month.name) \(day)", consumeEnd)
    }

    private func parseYearWords(_ words: [String]) -> Int {
        // Handle "twenty twenty six" → 2026 (spoken as two two-digit numbers)
        if words.count >= 2 {
            let first = parseNumber(Array(words.prefix(1)))
            let rest = parseNumber(Array(words.dropFirst()))
            // "twenty twenty six" → 20 + 26 = 2026-ish
            if first >= 19 && first <= 21 && rest >= 0 && rest <= 99 {
                return first * 100 + rest
            }
        }
        // Try normal parse
        return parseNumber(words)
    }

    private func ordinalToNumber(_ word: String) -> Int {
        if let ordinal = SmartFormattingRules.ordinalOnes[word] {
            return Int(ordinal.filter(\.isNumber)) ?? 0
        }
        if let ordinal = SmartFormattingRules.ordinalTens[word] {
            return Int(ordinal.filter(\.isNumber)) ?? 0
        }
        return 0
    }

    // MARK: - Time Parsing

    private func tryParseTime(words: [String], numberWords: [String], numberEndIndex: Int) -> (String, Int)? {
        let hourValue = parseNumber(numberWords)
        guard hourValue >= 1 && hourValue <= 12 else { return nil }

        var endIdx = numberEndIndex

        // Check for minutes
        var minutes: Int? = nil
        if endIdx < words.count {
            let nextLower = words[endIdx].lowercased()
            if SmartFormattingRules.ones[nextLower] != nil || SmartFormattingRules.tens[nextLower] != nil {
                let (minWords, minEnd) = collectNumberWords(words, from: endIdx)
                let minValue = parseNumber(minWords)
                if minValue >= 0 && minValue <= 59 {
                    // Check that the word after minutes is am/pm (to confirm this is a time)
                    let afterMin = minEnd < words.count ? words[minEnd].lowercased() : ""
                    if afterMin == "am" || afterMin == "pm" || afterMin == "a.m." || afterMin == "p.m." {
                        minutes = minValue
                        endIdx = minEnd
                    }
                }
            }
        }

        // Check for am/pm
        if endIdx < words.count {
            let ampm = words[endIdx].lowercased()
            if ampm == "am" || ampm == "a.m." {
                let minStr = minutes.map { String(format: "%02d", $0) } ?? "00"
                return ("\(hourValue):\(minStr) AM", endIdx + 1)
            } else if ampm == "pm" || ampm == "p.m." {
                let minStr = minutes.map { String(format: "%02d", $0) } ?? "00"
                return ("\(hourValue):\(minStr) PM", endIdx + 1)
            }
        }

        // No am/pm — if we have minutes, format without am/pm
        if let mins = minutes {
            return ("\(hourValue):\(String(format: "%02d", mins))", endIdx)
        }

        return nil
    }

    // MARK: - Phone Number Parsing

    private func tryParsePhoneNumber(words: [String], from start: Int) -> (String, Int)? {
        // Collect consecutive single-digit number words
        var digits: [Int] = []
        var j = start
        while j < words.count {
            let w = words[j].lowercased()
            if let d = SmartFormattingRules.ones[w], d >= 0, d <= 9 {
                digits.append(d)
                j += 1
            } else if w == "oh" || w == "o" {
                digits.append(0)
                j += 1
            } else {
                break
            }
        }

        if digits.count == 7 {
            let formatted = digits[0..<3].map(String.init).joined() + "-" +
                           digits[3..<7].map(String.init).joined()
            return (formatted, j)
        }

        if digits.count == 10 {
            let formatted = "(\(digits[0..<3].map(String.init).joined())) " +
                           digits[3..<6].map(String.init).joined() + "-" +
                           digits[6..<10].map(String.init).joined()
            return (formatted, j)
        }

        return nil
    }

    private func tryParsePhoneWithAreaCode(words: [String], from start: Int) -> (String, Int)? {
        // After "area code", collect digits
        var digits: [Int] = []
        var j = start
        while j < words.count {
            let w = words[j].lowercased()
            if let d = SmartFormattingRules.ones[w], d >= 0, d <= 9 {
                digits.append(d)
                j += 1
            } else if w == "oh" || w == "o" {
                digits.append(0)
                j += 1
            } else {
                break
            }
        }

        if digits.count == 10 {
            let formatted = "(\(digits[0..<3].map(String.init).joined())) " +
                           digits[3..<6].map(String.init).joined() + "-" +
                           digits[6..<10].map(String.init).joined()
            return (formatted, j)
        }

        if digits.count == 7 {
            // Area code was the first 3 of a 10-digit sequence, but collected as separate group
            return nil
        }

        return nil
    }

    // MARK: - Number Word Collection

    private func collectNumberWords(_ words: [String], from start: Int) -> (words: [String], endIndex: Int) {
        var numberWords: [String] = []
        var j = start
        while j < words.count {
            let w = words[j].lowercased()
            if SmartFormattingRules.allNumberWords.contains(w) {
                if w == "and" {
                    // "and" only valid between number words
                    if j + 1 < words.count &&
                       SmartFormattingRules.allNumberWords.contains(words[j + 1].lowercased()) &&
                       words[j + 1].lowercased() != "and" {
                        numberWords.append(w)
                    } else {
                        break
                    }
                } else {
                    numberWords.append(w)
                }
                j += 1
            } else {
                break
            }
        }
        return (numberWords, j)
    }

    // MARK: - Number Parsing

    private func parseNumber(_ words: [String]) -> Int {
        let filtered = words.filter { $0 != "and" }
        var total = 0
        var current = 0

        for word in filtered {
            if let value = SmartFormattingRules.ones[word] {
                current += value
            } else if let value = SmartFormattingRules.tens[word] {
                current += value
            } else if word == "hundred" {
                current = (current == 0 ? 1 : current) * 100
            } else if let magnitude = SmartFormattingRules.magnitudes[word], magnitude >= 1000 {
                current = (current == 0 ? 1 : current) * magnitude
                total += current
                current = 0
            }
        }

        return total + current
    }

    // MARK: - Comma Formatting

    private func formatWithCommas(_ value: Int) -> String {
        if value >= 1000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            return formatter.string(from: NSNumber(value: value)) ?? String(value)
        }
        return String(value)
    }

    // MARK: - Ordinal Helpers

    private func shouldKeepOrdinal(_ word: String, words: [String], index: Int) -> Bool {
        let sentence = words.joined(separator: " ")
        return DisambiguatingMatcher.anyPatternMatches(SmartFormattingRules.ordinalKeepPatterns, in: sentence)
    }

    // MARK: - Single Number Word Keep Patterns

    private static let singleNumberKeepPatterns: [String] = [
        #"(?i)\bno\s+one\b"#,
        #"(?i)\bone\s+of\b"#,
        #"(?i)\bone\s+another\b"#,
        #"(?i)\bfor\s+one\b"#,
        #"(?i)\bone\s+more\b"#,
        #"(?i)\bone\s+day\b"#,
        #"(?i)\bone\s+time\b"#,
        #"(?i)\bone\s+thing\b"#,
        #"(?i)\bone\s+way\b"#,
        #"(?i)\bat\s+one\s+point\b"#,
        #"(?i)\bone\s+by\s+one\b"#,
        #"(?i)\bone\s+question\b"#,
    ]

    private static let smallNumberBeforeNounKeepPatterns: [String] = [
        #"(?i)\b(two|three|four|five|six|seven|eight|nine)\s+(question|questions|concern|concerns|thing|things|people|person|way|ways|time|times|day|days|week|weeks|month|months|year|years|minute|minutes|hour|hours|option|options|choice|choices|reason|reasons|point|points|step|steps|item|items|issue|issues|idea|ideas|problem|problems|example|examples|type|types|kind|kinds|part|parts|piece|pieces|group|groups|set|sets|pair|pairs|team|teams|member|members|cat|cats|dog|dogs|kid|kids|child|children|friend|friends|night|nights|attempt|attempts|chance|chances|engineer|engineers|developer|developers|reps|rep)\b"#,
    ]

    private func shouldKeepNumberWord(_ word: String, words: [String], index: Int) -> Bool {
        let sentence = words.joined(separator: " ")
        if word == "one" {
            return DisambiguatingMatcher.anyPatternMatches(Self.singleNumberKeepPatterns, in: sentence)
        }
        // Small numbers (2-9) before common nouns: keep as words
        if let val = SmartFormattingRules.ones[word], val >= 2, val <= 9 {
            return DisambiguatingMatcher.anyPatternMatches(Self.smallNumberBeforeNounKeepPatterns, in: sentence)
        }
        return false
    }

    private func ordinalSuffix(for n: Int) -> String {
        let mod100 = n % 100
        if mod100 >= 11 && mod100 <= 13 { return "th" }
        switch n % 10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }
}
