import Foundation

/// Matches transcribed text against auto-generated smart home commands
struct SmartHomeCommandMatcher {

    /// Filler words to strip before matching
    private static let fillerWords: Set<String> = [
        "the", "my", "please", "um", "uh", "like", "just", "can", "you",
        "hey", "ok", "okay", "so", "well", "actually",
    ]

    /// Brightness pattern: "set <target> to <N> percent"
    private static let brightnessPattern = try! NSRegularExpression(
        pattern: #"(?:set|change)\s+(.+?)\s+to\s+(\d+)\s*(?:percent|%)"#,
        options: .caseInsensitive
    )

    /// Try to match transcribed text against known commands.
    /// Returns the matched command and any parsed brightness value.
    static func match(text: String, commands: [SmartHomeCommand]) -> SmartHomeMatchResult? {
        let cleaned = stripFillers(text)

        // First try brightness pattern (has a dynamic value to extract)
        if let brightnessResult = matchBrightness(cleaned, commands: commands) {
            return brightnessResult
        }

        // Then try exact phrase matching
        for command in commands {
            for phrase in command.triggerPhrases {
                if cleaned == phrase {
                    return SmartHomeMatchResult(command: command, parsedBrightness: nil)
                }
            }
        }

        return nil
    }

    /// Strip filler words, lowercase, and normalize whitespace
    static func stripFillers(_ text: String) -> String {
        let words = text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .filter { !fillerWords.contains(String($0)) }
        return words.joined(separator: " ")
    }

    /// Try to match a brightness command like "set desk lamp to 50 percent"
    private static func matchBrightness(_ text: String, commands: [SmartHomeCommand]) -> SmartHomeMatchResult? {
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)

        guard let match = brightnessPattern.firstMatch(in: text, range: range) else {
            return nil
        }

        guard let targetRange = Range(match.range(at: 1), in: text),
              let valueRange = Range(match.range(at: 2), in: text) else {
            return nil
        }

        let targetName = stripFillers(String(text[targetRange]))
        guard let brightness = Int(text[valueRange]), brightness >= 0, brightness <= 100 else {
            return nil
        }

        // Find a command whose target name matches
        for command in commands where command.action == .turnOn || command.action == .turnOff {
            let commandTargetNormalized = command.targetName.lowercased()
            if targetName == commandTargetNormalized || targetName == command.targetName.lowercased().replacingOccurrences(of: " lights", with: "") {
                // Create a synthetic setBrightness result using the matched light
                let brightnessCommand = SmartHomeCommand(
                    triggerPhrases: [],
                    action: .setBrightness,
                    targetLightId: command.targetLightId,
                    targetName: command.targetName,
                    isRoomLevel: command.isRoomLevel
                )
                return SmartHomeMatchResult(command: brightnessCommand, parsedBrightness: brightness)
            }
        }

        return nil
    }
}
