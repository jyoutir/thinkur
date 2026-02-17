import Foundation

struct OperatorMatcher {
    /// Apply spoken operator replacements using CodeContextRules.operators.
    static func applyOperators(in text: String) -> (text: String, corrections: [CorrectionEntry]) {
        PhraseMatcher.applyReplacements(
            to: text,
            rules: CodeContextRules.operators,
            processorName: "CodeContext"
        )
    }
}
