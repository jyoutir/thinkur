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
            let pattern = #"(?i)\b"# + NSRegularExpression.escapedPattern(for: contraction.expanded) + #"\b"#
            let (newText, mutations) = TextMutator.replaceAll(in: result, pattern: pattern, replacement: contraction.contracted)
            if !mutations.isEmpty {
                for mutation in mutations {
                    corrections.append(CorrectionEntry(
                        processorName: name, ruleName: "casual_contraction",
                        originalFragment: mutation.original, replacement: contraction.contracted,
                        confidence: 0.85
                    ))
                }
                result = newText
            }
        }

        // Strip sign-offs in casual mode
        result = stripCasualSignOff(result, corrections: &corrections)

        // Strip trailing period from single sentences
        if !result.contains(". ") && result.hasSuffix(".") {
            corrections.append(CorrectionEntry(
                processorName: name, ruleName: "casual_strip_period",
                originalFragment: ".", replacement: "", confidence: 0.8
            ))
            result = String(result.dropLast())
        }

        // Lowercase first character for casual feel
        if let first = result.first, first.isUppercase && result.count > 1 {
            let secondIndex = result.index(after: result.startIndex)
            let second = result[secondIndex]

            let firstStr = String(first)
            let shouldKeepUpper =
                (firstStr == "I" && (second == " " || second == "'" || secondIndex == result.endIndex)) ||
                second.isUppercase ||
                isSpecialCasedStart(result) ||
                isProperNounStart(result)

            if !shouldKeepUpper {
                let original = firstStr
                result = first.lowercased() + result.dropFirst()
                corrections.append(CorrectionEntry(
                    processorName: name, ruleName: "casual_lowercase",
                    originalFragment: original, replacement: first.lowercased(), confidence: 0.7
                ))
            }
        }

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

    // MARK: - Helpers

    private func isSpecialCasedStart(_ text: String) -> Bool {
        let firstWord = text.split(separator: " ").first?.lowercased() ?? ""
        return CapitalizationRules.specialCasing[firstWord] != nil
    }

    private func isProperNounStart(_ text: String) -> Bool {
        let firstWord = String(text.split(separator: " ").first ?? "").lowercased().trimmingCharacters(in: .punctuationCharacters)
        return CapitalizationRules.supplementaryProperNouns.contains(firstWord)
    }
}
