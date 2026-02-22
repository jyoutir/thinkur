import Foundation

struct ReplacementRule {
    let pattern: String
    let replacement: String
    let confidence: Float
    let isRegex: Bool
    let category: String

    init(pattern: String, replacement: String, confidence: Float = 1.0, isRegex: Bool = false, category: String = "") {
        self.pattern = pattern
        self.replacement = replacement
        self.confidence = confidence
        self.isRegex = isRegex
        self.category = category
    }
}
