import Foundation
import NaturalLanguage

struct CapitalizationProcessor: TextProcessor {
    let name = "Capitalization"

    func process(_ text: String, context: ProcessingContext) -> ProcessorResult {
        guard !text.isEmpty else { return ProcessorResult(text: text) }

        var result = text
        var corrections: [CorrectionEntry] = []

        // Phase 1: Capitalize sentence starts (after . ! ? and at beginning)
        let (afterStarts, startCorrections) = capitalizeSentenceStarts(result)
        result = afterStarts
        corrections.append(contentsOf: startCorrections)

        // Phase 2: Capitalize standalone "i" and contractions
        let (afterI, iCorrections) = capitalizeI(result)
        result = afterI
        corrections.append(contentsOf: iCorrections)

        // Phase 3: Special casing (iPhone, macOS, SwiftUI, etc.)
        let (afterSpecial, specialCorrections) = applySpecialCasing(result)
        result = afterSpecial
        corrections.append(contentsOf: specialCorrections)

        // Phase 4: Safe acronyms (api → API, url → URL)
        let (afterAcronyms, acronymCorrections) = uppercaseAcronyms(result)
        result = afterAcronyms
        corrections.append(contentsOf: acronymCorrections)

        // Phase 5: Supplementary proper nouns
        let (afterProper, properCorrections) = capitalizeSupplementaryProperNouns(result)
        result = afterProper
        corrections.append(contentsOf: properCorrections)

        // Phase 6: NLTagger proper nouns (existing behavior)
        let (afterTagger, taggerCorrections) = capitalizeProperNouns(result)
        result = afterTagger
        corrections.append(contentsOf: taggerCorrections)

        return ProcessorResult(text: result, corrections: corrections)
    }

    // MARK: - Sentence Start Capitalization

    private func capitalizeSentenceStarts(_ text: String) -> (String, [CorrectionEntry]) {
        var chars = Array(text)
        var corrections: [CorrectionEntry] = []
        var capitalizeNext = true

        for i in 0..<chars.count {
            if capitalizeNext && chars[i].isLetter {
                if chars[i].isLowercase {
                    let original = String(chars[i])
                    chars[i] = Character(chars[i].uppercased())
                    corrections.append(CorrectionEntry(
                        processorName: name,
                        ruleName: "sentence_start",
                        originalFragment: original,
                        replacement: String(chars[i]),
                        confidence: 0.95
                    ))
                }
                capitalizeNext = false
            } else if chars[i] == "." || chars[i] == "!" || chars[i] == "?" || chars[i] == "\n" {
                capitalizeNext = true
            }
        }

        return (String(chars), corrections)
    }

    // MARK: - "I" Capitalization

    private func capitalizeI(_ text: String) -> (String, [CorrectionEntry]) {
        var result = text
        var corrections: [CorrectionEntry] = []

        // Standalone "i"
        if let regex = RegexCache.shared.regex(for: CapitalizationRules.standaloneIPattern) {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: nsRange)
            for match in matches.reversed() {
                guard let range = Range(match.range, in: result) else { continue }
                corrections.append(CorrectionEntry(
                    processorName: name, ruleName: "standalone_i",
                    originalFragment: "i", replacement: "I", confidence: 0.99
                ))
                result.replaceSubrange(range, with: "I")
            }
        }

        // "i'm", "i'd", "i'll", "i've"
        if let regex = RegexCache.shared.regex(for: CapitalizationRules.contractionIPattern) {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: nsRange)
            for match in matches.reversed() {
                guard let range = Range(match.range, in: result) else { continue }
                let original = String(result[range])
                let replacement = "I'" + original.dropFirst(2)
                corrections.append(CorrectionEntry(
                    processorName: name, ruleName: "contraction_i",
                    originalFragment: original, replacement: String(replacement), confidence: 0.99
                ))
                result.replaceSubrange(range, with: replacement)
            }
        }

        return (result, corrections)
    }

    // MARK: - Special Casing

    private func applySpecialCasing(_ text: String) -> (String, [CorrectionEntry]) {
        var result = text
        var corrections: [CorrectionEntry] = []

        for (lower, correct) in CapitalizationRules.specialCasing {
            let pattern = #"(?i)\b"# + NSRegularExpression.escapedPattern(for: lower) + #"\b"#
            let (newText, mutations) = TextMutator.replaceAll(in: result, pattern: pattern, replacement: correct)
            if !mutations.isEmpty {
                for mutation in mutations {
                    if mutation.original.lowercased() == lower {
                        corrections.append(CorrectionEntry(
                            processorName: name, ruleName: "special_casing",
                            originalFragment: mutation.original, replacement: correct, confidence: 0.95
                        ))
                    }
                }
                result = newText
            }
        }

        return (result, corrections)
    }

    // MARK: - Safe Acronyms

    private func uppercaseAcronyms(_ text: String) -> (String, [CorrectionEntry]) {
        let words = text.split(separator: " ", omittingEmptySubsequences: true)
        var resultWords: [String] = []
        var corrections: [CorrectionEntry] = []

        for word in words {
            let clean = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
            if CapitalizationRules.safeAcronyms.contains(clean) && String(word) != clean.uppercased() {
                // Preserve any trailing punctuation
                let trailing = word.reversed().prefix(while: { $0.isPunctuation })
                let upper = clean.uppercased() + String(trailing.reversed())
                corrections.append(CorrectionEntry(
                    processorName: name, ruleName: "acronym",
                    originalFragment: String(word), replacement: upper, confidence: 0.9
                ))
                resultWords.append(upper)
            } else {
                resultWords.append(String(word))
            }
        }

        return (resultWords.joined(separator: " "), corrections)
    }

    // MARK: - Supplementary Proper Nouns

    private func capitalizeSupplementaryProperNouns(_ text: String) -> (String, [CorrectionEntry]) {
        let words = text.split(separator: " ", omittingEmptySubsequences: true)
        var resultWords: [String] = []
        var corrections: [CorrectionEntry] = []

        for word in words {
            let clean = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
            if CapitalizationRules.supplementaryProperNouns.contains(clean) {
                let current = String(word)
                // Don't re-capitalize if already special-cased or uppercase
                if current.first?.isLowercase == true {
                    let trailing = word.reversed().prefix(while: { $0.isPunctuation })
                    let capitalized = clean.prefix(1).uppercased() + clean.dropFirst() + String(trailing.reversed())
                    corrections.append(CorrectionEntry(
                        processorName: name, ruleName: "proper_noun",
                        originalFragment: current, replacement: capitalized, confidence: 0.8
                    ))
                    resultWords.append(capitalized)
                } else {
                    resultWords.append(current)
                }
            } else {
                resultWords.append(String(word))
            }
        }

        return (resultWords.joined(separator: " "), corrections)
    }

    // MARK: - NLTagger Proper Nouns

    private func capitalizeProperNouns(_ text: String) -> (String, [CorrectionEntry]) {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        var result = text
        var corrections: [CorrectionEntry] = []
        var replacements: [(Range<String.Index>, String)] = []

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if let tag, tag == .personalName || tag == .placeName || tag == .organizationName {
                let word = String(text[range])
                if word.first?.isLowercase == true {
                    let capitalized = word.prefix(1).uppercased() + word.dropFirst()
                    replacements.append((range, capitalized))
                    corrections.append(CorrectionEntry(
                        processorName: name, ruleName: "nltagger_proper_noun",
                        originalFragment: word, replacement: capitalized, confidence: 0.75
                    ))
                }
            }
            return true
        }

        for (range, replacement) in replacements.reversed() {
            result.replaceSubrange(range, with: replacement)
        }

        return (result, corrections)
    }
}
