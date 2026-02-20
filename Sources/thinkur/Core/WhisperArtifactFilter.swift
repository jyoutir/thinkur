import Foundation

enum WhisperArtifactFilter {
    /// Lowercased bracket tokens WhisperKit emits for non-speech audio.
    /// Using an explicit allowlist avoids false positives on real text with brackets.
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

    /// Returns true if `word` (trimmed, lowercased) is a Whisper noise token.
    static func isArtifact(_ word: String) -> Bool {
        noiseTokens.contains(word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    /// Removes all Whisper noise tokens from `text` and normalises whitespace.
    /// Returns `nil` if nothing meaningful remains after stripping.
    static func strip(_ text: String) -> String? {
        var result = text
        for token in noiseTokens {
            result = result.replacingOccurrences(
                of: token, with: "",
                options: [.caseInsensitive],
                range: result.startIndex..<result.endIndex
            )
        }
        result = result
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }
}
