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

                // 3b. Currency: "fifty dollars" → "$50"
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
                            formatted = "\(currency.symbol)\(value)"
                        } else {
                            formatted = "\(value)\(currency.symbol)"
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
                    // Avoid converting ordinal-context "third" / "fourth"
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

                // 3f. Time: number followed by "o'clock" or small number (1-59 for minutes)
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

                // 3g. Cardinal: number words → digits
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

                // 3h. Single number word → digit (unless idiomatic)
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
    ]

    private func shouldKeepNumberWord(_ word: String, words: [String], index: Int) -> Bool {
        if word == "one" {
            let sentence = words.joined(separator: " ")
            return DisambiguatingMatcher.anyPatternMatches(Self.singleNumberKeepPatterns, in: sentence)
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
