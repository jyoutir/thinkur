import Foundation

/// Result of matching a rename voice command
struct RenameMatch {
    let oldName: String   // normalized (lowercased, trimmed)
    let newName: String   // as-spoken
}

/// Matches voice text against rename patterns like "rename X to Y" or "call X Y"
struct SmartHomeRenameMatcher {

    private static let fillerWords: Set<String> = [
        "the", "my", "please", "um", "uh", "like", "just", "can", "you",
        "hey", "ok", "okay", "so", "well", "actually",
    ]

    /// Patterns: "rename X to Y", "call X Y"
    private static let renamePatterns: [(regex: NSRegularExpression, oldGroup: Int, newGroup: Int)] = {
        let patterns: [(String, Int, Int)] = [
            (#"rename\s+(.+?)\s+to\s+(.+)"#, 1, 2),
            (#"call\s+(.+?)\s+(.+)"#, 1, 2),
        ]
        return patterns.compactMap { pattern, old, new in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
            return (regex, old, new)
        }
    }()

    /// Try to match a rename command from transcribed text
    static func matchRename(text: String) -> RenameMatch? {
        let cleaned = stripFillers(text)

        for (regex, oldGroup, newGroup) in renamePatterns {
            let nsText = cleaned as NSString
            let range = NSRange(location: 0, length: nsText.length)

            guard let match = regex.firstMatch(in: cleaned, range: range) else { continue }
            guard let oldRange = Range(match.range(at: oldGroup), in: cleaned),
                  let newRange = Range(match.range(at: newGroup), in: cleaned) else { continue }

            let oldName = String(cleaned[oldRange]).trimmingCharacters(in: .whitespaces).lowercased()
            let newName = String(cleaned[newRange]).trimmingCharacters(in: .whitespaces)

            guard !oldName.isEmpty, !newName.isEmpty else { continue }
            return RenameMatch(oldName: oldName, newName: newName)
        }

        return nil
    }

    private static func stripFillers(_ text: String) -> String {
        let words = text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .filter { !fillerWords.contains(String($0)) }
        return words.joined(separator: " ")
    }
}
