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
            return ProcessorResult(text: text)
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

        // Expand contractions: "don't" → "do not", "I'm" → "I am"
        for expansion in StyleAdaptationRules.formalExpansions {
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

        // Ensure trailing punctuation
        if let last = result.last, !last.isPunctuation {
            corrections.append(CorrectionEntry(
                processorName: name, ruleName: "formal_period",
                originalFragment: "", replacement: ".", confidence: 0.8
            ))
            result += "."
        }

        return ProcessorResult(text: result, corrections: corrections)
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
