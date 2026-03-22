import Foundation

struct StyleAdaptationProcessor: TextProcessor {
    let name = "StyleAdaptation"

    func process(_ text: String, context: ProcessingContext) -> ProcessorResult {
        guard !text.isEmpty else { return ProcessorResult(text: text) }

        switch context.appStyle {
        case .casual:
            return applyCasualStyle(text)
        case .formal:
            return applyFormalStyle(text)
        case .code:
            return ProcessorResult(text: text)
        case .standard:
            return applyStandardStyle(text)
        }
    }

    // MARK: - Casual Style

    private func applyCasualStyle(_ text: String) -> ProcessorResult {
        var result = text
        var corrections: [CorrectionEntry] = []

        // Apply contractions: "I am" → "I'm", "do not" → "don't"
        for contraction in StyleAdaptationRules.casualContractions {
            let escaped = NSRegularExpression.escapedPattern(for: contraction.expanded)
            let pattern: String
            if contraction.expanded.hasSuffix(" have") {
                // Skip "have" contractions before digit, "to", or noun-phrase starters
                pattern = #"(?i)\b"# + escaped + #"\b(?!\s+(\d|to\b|a\b|an\b|the\b|one\b|two\b|three\b|four\b|five\b|some\b|any\b|no\b))"#
            } else {
                pattern = #"(?i)\b"# + escaped + #"\b"#
            }
            let (newText, mutations) = TextMutator.replaceAll(in: result, pattern: pattern, replacement: contraction.contracted)
            for mutation in mutations {
                corrections.append(CorrectionEntry(
                    processorName: name, ruleName: "casual_contraction",
                    originalFragment: mutation.original, replacement: contraction.contracted,
                    confidence: 0.85
                ))
            }
            if !mutations.isEmpty { result = newText }
        }

        // Strip sign-offs in casual mode
        result = stripCasualSignOff(result, corrections: &corrections)

        // Strip trailing period in casual mode
        if result.hasSuffix(".") && !result.hasSuffix("...") {
            corrections.append(CorrectionEntry(
                processorName: name, ruleName: "casual_strip_period",
                originalFragment: ".", replacement: "", confidence: 0.8
            ))
            result = String(result.dropLast())
        }

        // Full casual lowercasing: lowercase everything except special casing and acronyms
        result = applyCasualLowercasing(result, corrections: &corrections)

        return ProcessorResult(text: result, corrections: corrections)
    }

    // MARK: - Formal Style

    private func applyFormalStyle(_ text: String) -> ProcessorResult {
        var result = text.trimmingCharacters(in: .whitespaces)
        var corrections: [CorrectionEntry] = []

        // Pre-pass: handle "it's" + past participle → "it has" before generic expansion
        result = expandItsContextually(result, corrections: &corrections)

        // Expand contractions: "don't" → "do not", "I'm" → "I am"
        for expansion in StyleAdaptationRules.formalExpansions {
            // Skip possessive 's — only expand pronoun contractions
            if expansion.contracted.hasSuffix("'s") {
                let pattern = #"(?i)\b"# + NSRegularExpression.escapedPattern(for: expansion.contracted) + #"\b"#
                guard let regex = RegexCache.shared.regex(for: pattern) else { continue }
                let nsRange = NSRange(result.startIndex..., in: result)
                let matches = regex.matches(in: result, range: nsRange)

                for match in matches.reversed() {
                    guard let range = Range(match.range, in: result) else { continue }
                    let matched = String(result[range])
                    let matchedPronoun = String(matched.dropLast(2)).lowercased()
                    // Only expand known pronoun contractions, skip possessives
                    if StyleAdaptationRules.pronounsWithContractions.contains(matchedPronoun) {
                        result.replaceSubrange(range, with: expansion.expanded)
                        corrections.append(CorrectionEntry(
                            processorName: name, ruleName: "formal_expansion",
                            originalFragment: matched, replacement: expansion.expanded,
                            confidence: 0.85
                        ))
                    }
                }
            } else {
                let pattern = #"(?i)\b"# + NSRegularExpression.escapedPattern(for: expansion.contracted) + #"\b"#
                let (newText, mutations) = TextMutator.replaceAll(in: result, pattern: pattern, replacement: expansion.expanded)
                if !mutations.isEmpty {
                    for mutation in mutations {
                        corrections.append(CorrectionEntry(
                            processorName: name, ruleName: "formal_expansion",
                            originalFragment: mutation.original, replacement: expansion.expanded,
                            confidence: 0.85
                        ))
                    }
                    result = newText
                }
            }
        }

        // Re-capitalize sentence starts after contraction expansion
        result = recapitalizeSentenceStarts(result)

        // Insert commas after introductory phrases
        result = insertIntroductoryCommas(result, corrections: &corrections)

        // Format sign-offs for formal style
        result = formatFormalSignOff(result, corrections: &corrections)

        // Format greetings for formal style
        result = formatFormalGreeting(result, corrections: &corrections)

        // Ensure trailing punctuation (only if no sign-off was formatted, which handles its own)
        if let last = result.last, !last.isPunctuation && !result.hasSuffix("\n") {
            corrections.append(CorrectionEntry(
                processorName: name, ruleName: "formal_period",
                originalFragment: "", replacement: ".", confidence: 0.8
            ))
            result += "."
        }

        return ProcessorResult(text: result, corrections: corrections)
    }

    /// Expand "it's" contextually: "it has" before past participles, "it is" otherwise.
    /// Must run BEFORE the generic expansion loop.
    private func expandItsContextually(_ text: String, corrections: inout [CorrectionEntry]) -> String {
        var result = text
        let pattern = #"(?i)\bit's\b"#
        guard let regex = RegexCache.shared.regex(for: pattern) else { return result }
        let nsRange = NSRange(result.startIndex..., in: result)
        let matches = regex.matches(in: result, range: nsRange)

        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let afterIndex = range.upperBound
            // Get the next word after "it's"
            let remaining = result[afterIndex...].drop(while: { $0 == " " })
            let nextWord = String(remaining.prefix(while: { $0.isLetter })).lowercased()

            let expansion: String
            if StyleAdaptationRules.pastParticiples.contains(nextWord) {
                expansion = "It has"
            } else {
                expansion = "It is"
            }

            // Preserve original casing of "It"
            let matched = String(result[range])
            let finalExpansion: String
            if matched.first?.isUppercase == true {
                finalExpansion = expansion
            } else {
                finalExpansion = expansion.lowercased()
            }

            corrections.append(CorrectionEntry(
                processorName: name, ruleName: "formal_its_expansion",
                originalFragment: matched, replacement: finalExpansion,
                confidence: 0.9
            ))
            result.replaceSubrange(range, with: finalExpansion)
        }

        return result
    }

    // MARK: - Standard Style

    private func applyStandardStyle(_ text: String) -> ProcessorResult {
        var result = text.trimmingCharacters(in: .whitespaces)
        var corrections: [CorrectionEntry] = []

        // Insert commas after introductory phrases
        result = insertIntroductoryCommas(result, corrections: &corrections)

        // Add trailing period if text doesn't end with terminal punctuation
        if !result.isEmpty, let last = result.last, !".!?".contains(last) {
            corrections.append(CorrectionEntry(
                processorName: name, ruleName: "standard_period",
                originalFragment: "", replacement: ".", confidence: 0.8
            ))
            result += "."
        }

        return ProcessorResult(text: result, corrections: corrections)
    }

    // MARK: - Sign-Off Formatting

    private static let signOffPhrases: [String] = [
        "best regards", "kind regards", "warm regards", "regards",
        "sincerely", "thanks", "thank you", "cheers",
    ]

    private func stripCasualSignOff(_ text: String, corrections: inout [CorrectionEntry]) -> String {
        let lower = text.lowercased()
        for phrase in Self.signOffPhrases {
            if lower.hasSuffix(phrase) {
                let start = text.index(text.endIndex, offsetBy: -phrase.count)
                var result = String(text[text.startIndex..<start]).trimmingCharacters(in: .whitespaces)
                // Remove trailing punctuation before sign-off
                while result.hasSuffix(".") || result.hasSuffix(",") {
                    result = String(result.dropLast()).trimmingCharacters(in: .whitespaces)
                }
                corrections.append(CorrectionEntry(
                    processorName: name, ruleName: "casual_strip_signoff",
                    originalFragment: phrase, replacement: "", confidence: 0.8
                ))
                return result
            }
        }
        return text
    }

    private func formatFormalSignOff(_ text: String, corrections: inout [CorrectionEntry]) -> String {
        let lower = text.lowercased()
        for phrase in Self.signOffPhrases {
            if lower.hasSuffix(phrase) {
                let start = text.index(text.endIndex, offsetBy: -phrase.count)
                var body = String(text[text.startIndex..<start]).trimmingCharacters(in: .whitespaces)
                let signOff = String(text[start...])

                // Ensure body ends with punctuation
                if !body.isEmpty, let last = body.last, !".!?".contains(last) {
                    body += "."
                }

                // Capitalize sign-off
                let capitalizedSignOff = signOff.prefix(1).uppercased() + signOff.dropFirst()

                return "\(body)\n\n\(capitalizedSignOff)."
            }
        }
        return text
    }

    // MARK: - Greeting Formatting

    private func formatFormalGreeting(_ text: String, corrections: inout [CorrectionEntry]) -> String {
        let lower = text.lowercased()
        // "Dear Sarah," at start → "Dear Sarah,\n\n"
        guard let regex = RegexCache.shared.regex(for: #"(?i)^dear\s+\w+\s*,"#) else { return text }
        let nsRange = NSRange(text.startIndex..., in: text)
        if let match = regex.firstMatch(in: lower, range: nsRange),
           let range = Range(match.range, in: text) {
            let greeting = String(text[range])
            let rest = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !rest.isEmpty {
                return "\(greeting)\n\n\(rest)"
            }
        }
        return text
    }

    // MARK: - Sentence Re-Capitalization

    /// Re-capitalize sentence starts after contraction expansion may have lowercased them.
    private func recapitalizeSentenceStarts(_ text: String) -> String {
        var chars = Array(text)
        var capitalizeNext = true
        var i = 0
        while i < chars.count {
            if capitalizeNext {
                if chars[i].isLetter {
                    if chars[i].isLowercase {
                        chars[i] = Character(chars[i].uppercased())
                    }
                    capitalizeNext = false
                } else if chars[i].isNumber {
                    // Skip entire numeric token (e.g., "1st") — don't capitalize letters inside it
                    while i < chars.count && chars[i] != " " && chars[i] != "\n" {
                        i += 1
                    }
                    capitalizeNext = false
                    continue
                }
            } else if chars[i] == "!" || chars[i] == "?" || chars[i] == "\n" {
                capitalizeNext = true
            } else if chars[i] == "." {
                let partOfEllipsis = (i > 0 && chars[i - 1] == ".") || (i + 1 < chars.count && chars[i + 1] == ".")
                let inlineURL = !partOfEllipsis && (i + 1 < chars.count && chars[i + 1].isLetter)
                if !partOfEllipsis && !inlineURL { capitalizeNext = true }
            }
            i += 1
        }
        return String(chars)
    }

    // MARK: - Introductory Comma Insertion

    /// Common introductory phrases that should be followed by a comma in formal/standard style.
    private static let introductoryPhrases: [(pattern: String, replacement: String)] = [
        (#"(?i)^(I mean)\s+"#, "$1, "),
        (#"(?i)^(On second thought)\s+"#, "$1, "),
        (#"(?i)^(For example)\s+"#, "$1, "),
        (#"(?i)^(In fact)\s+"#, "$1, "),
        (#"(?i)^(So yeah)[,]?\s+"#, "$1, "),
        (#"(?i)^(Well)\s+"#, "$1, "),
        (#"(?i)^(Yeah)\s+"#, "$1, "),
        (#"(?i)^(Hey)[,]?\s+"#, "$1, "),
        (#"(?i)^(No)\s+"#, "$1, "),
        (#"(?i)^(Sorry)\s+"#, "$1, "),
        (#"(?i)^(Yes)\s+"#, "$1, "),
    ]

    /// Comma before trailing clauses.
    private static let trailingCommaPhrases: [(pattern: String, replacement: String)] = [
        (#"(?i)\s+(whichever\b)"#, ", $1"),
        (#"(?i)\s+(whatever\b)"#, ", $1"),
    ]

    private func insertIntroductoryCommas(_ text: String, corrections: inout [CorrectionEntry]) -> String {
        var result = text

        // Apply introductory phrases to each sentence
        let sentences = result.components(separatedBy: ". ")
        let rebuilt = sentences.map { sentence -> String in
            var s = sentence
            for (pattern, replacement) in Self.introductoryPhrases {
                guard let regex = RegexCache.shared.regex(for: pattern) else { continue }
                let nsRange = NSRange(s.startIndex..., in: s)
                let newS = regex.stringByReplacingMatches(in: s, range: nsRange, withTemplate: replacement)
                if newS != s {
                    corrections.append(CorrectionEntry(
                        processorName: name, ruleName: "introductory_comma",
                        originalFragment: "", replacement: ",", confidence: 0.75
                    ))
                    s = newS
                }
            }
            return s
        }
        result = rebuilt.joined(separator: ". ")

        // Trailing comma phrases
        for (pattern, replacement) in Self.trailingCommaPhrases {
            if let regex = RegexCache.shared.regex(for: pattern) {
                let nsRange = NSRange(result.startIndex..., in: result)
                let newResult = regex.stringByReplacingMatches(in: result, range: nsRange, withTemplate: replacement)
                if newResult != result {
                    corrections.append(CorrectionEntry(
                        processorName: name, ruleName: "trailing_comma",
                        originalFragment: "", replacement: ",", confidence: 0.75
                    ))
                    result = newResult
                }
            }
        }

        return result
    }

    // MARK: - Casual Full Lowercasing

    /// Lowercase everything in casual mode except special casing and acronyms.
    private func applyCasualLowercasing(_ text: String, corrections: inout [CorrectionEntry]) -> String {
        let words = text.split(separator: " ", omittingEmptySubsequences: true)
        var resultWords: [String] = []

        for word in words {
            let wordStr = String(word)
            let clean = word.lowercased().trimmingCharacters(in: .punctuationCharacters)

            // Keep special casing (iPhone, macOS, SwiftUI, etc.)
            if CapitalizationRules.specialCasing[clean] != nil {
                resultWords.append(wordStr)
                continue
            }

            // Keep acronyms (API, URL, etc.)
            if CapitalizationRules.safeAcronyms.contains(clean) {
                resultWords.append(wordStr)
                continue
            }

            // Keep standalone "I" pronoun (always uppercase, even in casual mode)
            if clean == "i" {
                let preserved = "I" + wordStr.dropFirst()
                resultWords.append(preserved)
                continue
            }

            // Lowercase everything else
            let lowered = wordStr.lowercased()
            if lowered != wordStr {
                corrections.append(CorrectionEntry(
                    processorName: name, ruleName: "casual_lowercase",
                    originalFragment: wordStr, replacement: lowered, confidence: 0.7
                ))
            }
            resultWords.append(lowered)
        }

        return resultWords.joined(separator: " ")
    }

}
