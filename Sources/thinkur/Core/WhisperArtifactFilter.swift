import Foundation

enum WhisperArtifactFilter {
    /// Lowercased bracket tokens WhisperKit emits for non-speech audio.
    private static let noiseTokens: Set<String> = [
        "[blank_audio]",
        "[music]",
        "[noise]",
        "[applause]",
        "[laughter]",
        "[speech]",
        "[inaudible]",
        "[speaking foreign language]",
        "[silence]",
    ]

    /// Matches any `[...]` or `(...)` annotation segment.
    private static let annotationPattern = try! NSRegularExpression(
        pattern: #"\[.*?\]|\(.*?\)"#, options: []
    )

    /// Returns true if `word` is a Whisper noise token or a bracket/paren annotation.
    static func isArtifact(_ word: String) -> Bool {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        if noiseTokens.contains(trimmed.lowercased()) { return true }
        if let first = trimmed.first, let last = trimmed.last {
            return (first == "[" && last == "]") || (first == "(" && last == ")")
        }
        return false
    }

    /// Removes all Whisper noise tokens and bracket/paren annotations from `text`
    /// and normalises whitespace. Returns `nil` if nothing meaningful remains.
    static func strip(_ text: String) -> String? {
        var result = text
        for token in noiseTokens {
            result = result.replacingOccurrences(
                of: token, with: "",
                options: [.caseInsensitive],
                range: result.startIndex..<result.endIndex
            )
        }
        // Strip any remaining [...] or (...) annotations
        result = annotationPattern.stringByReplacingMatches(
            in: result,
            range: NSRange(result.startIndex..., in: result),
            withTemplate: ""
        )
        result = result
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }
}
