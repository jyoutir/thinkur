import Foundation

struct ProcessorResult {
    let text: String
    let corrections: [CorrectionEntry]

    init(text: String, corrections: [CorrectionEntry] = []) {
        self.text = text
        self.corrections = corrections
    }
}

struct CorrectionEntry {
    let processorName: String
    let ruleName: String
    let originalFragment: String
    let replacement: String
    let confidence: Float
}

protocol TextProcessor {
    var name: String { get }
    func process(_ text: String, context: ProcessingContext) -> ProcessorResult
}

extension TextProcessor {
    /// Collapses multiple consecutive horizontal spaces into one and trims.
    func normalizeWhitespace(_ text: String) -> String {
        text.replacingOccurrences(of: "[\\t ]{2,}", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// Removes spaces before common punctuation marks.
    func cleanPunctuationSpacing(_ text: String) -> String {
        var result = text
        for mark in [".", ",", "?", "!", ":", ";"] {
            result = result.replacingOccurrences(of: " \(mark)", with: mark)
        }
        return result
    }
}

struct ProcessingContext {
    let frontmostAppBundleID: String
    let frontmostAppName: String
    let wordTimings: [WordTimingInfo]
    let appStyle: AppStyle
}

struct WordTimingInfo {
    let word: String
    let start: Float
    let end: Float
}

enum AppStyle {
    case casual
    case formal
    case code
    case standard
}
