import Foundation

enum ListDetectionRules {
    // MARK: - Numbered List Marker Patterns

    static let numberedMarkerPatterns: [ReplacementRule] = [
        // "number N" / "item N" / "step N" / "point N"
        ReplacementRule(pattern: #"\b(number|item|step|point)\s+(one|two|three|four|five|six|seven|eight|nine|ten|\d+)\b[.,:;]?\s*"#,
                       replacement: "", confidence: 0.9, isRegex: true, category: "numbered_marker"),
    ]

    // MARK: - Ordinal List Marker Patterns

    static let ordinalMarkerPatterns: [ReplacementRule] = [
        // "firstly", "secondly", "thirdly", etc.
        ReplacementRule(pattern: #"\b(firstly|secondly|thirdly|fourthly|fifthly|lastly|finally)[,:]?\s+"#,
                       replacement: "", confidence: 0.9, isRegex: true, category: "ordinal_marker"),
        // "first", "second", "third" as list markers (requires 2+ to confirm)
        ReplacementRule(pattern: #"\b(first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth)[,:]?\s+"#,
                       replacement: "", confidence: 0.7, isRegex: true, category: "ordinal_marker"),
    ]

    // MARK: - Bullet Marker Patterns

    static let bulletMarkerPatterns: [ReplacementRule] = [
        ReplacementRule(pattern: #"\b(bullet\s+point|bullet)\s+"#,
                       replacement: "", confidence: 0.9, isRegex: true, category: "bullet_marker"),
        ReplacementRule(pattern: #"\b(new|next)\s+(bullet|item|point)\s+"#,
                       replacement: "", confidence: 0.85, isRegex: true, category: "bullet_marker"),
    ]

    // MARK: - Continuation Marker Patterns

    static let continuationMarkerPatterns: [ReplacementRule] = [
        ReplacementRule(pattern: #"\b(add\s+another\s+item|next\s+item|add\s+item|another\s+item|and\s+another)\b\s*"#,
                       replacement: "", confidence: 0.85, isRegex: true, category: "continuation_marker"),
    ]

    // MARK: - Bare Number Marker Patterns (word-form and digit-form since SmartFormatting runs first)

    static let bareNumberMarkerPatterns: [ReplacementRule] = [
        ReplacementRule(pattern: #"\b(one|two|three|four|five|six|seven|eight|nine|ten|1|2|3|4|5|6|7|8|9|10)\b[,:]?\s+"#,
                       replacement: "", confidence: 0.7, isRegex: true, category: "bare_number_marker"),
    ]

    // MARK: - Bare Number Narrative Patterns (NOT a list)

    static let bareNumberNarrativePatterns: [String] = [
        #"(?i)\bone\s+of\s+(the|them|those|these|my|your|his|her|our|their)\b"#,
        #"(?i)\bat\s+one\s+point\b"#,
        #"(?i)\bno\s+one\b"#,
        #"(?i)\bone\s+more\b"#,
        #"(?i)\bone\s+another\b"#,
        #"(?i)\b(two|three|four|five|six|seven|eight|nine|ten)\s+(of|more|less|times|people|things|ways|days|weeks|months|years)\b"#,
    ]

    // MARK: - Ordinal Disambiguation (narrative use — NOT a list)

    static let ordinalNarrativePatterns: [String] = [
        // Preceded by article or possessive
        #"(?i)\b(the|a|my|your|his|her|our|their)\s+(first|second|third)\b"#,
        // Compound noun uses
        #"(?i)\b(first|second|third)\s+(thing|time|place|person|chance|thought|impression|attempt|step|day|week|month|year|half|quarter)\b"#,
        // Idioms
        #"(?i)\bat\s+first\b"#,
        #"(?i)\bfirst\s+of\s+all\b"#,
    ]

    // MARK: - Number Word to Int (for sequencing detection)

    static let numberWordToInt: [String: Int] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        "first": 1, "second": 2, "third": 3, "fourth": 4, "fifth": 5,
        "sixth": 6, "seventh": 7, "eighth": 8, "ninth": 9, "tenth": 10,
        "firstly": 1, "secondly": 2, "thirdly": 3, "fourthly": 4,
        "fifthly": 5, "lastly": 99, "finally": 99,
    ]

    // MARK: - List Formatting

    static let defaultBulletCharacter = "\u{2022} "
    static let nestedIndent = "   "   // 3 spaces for nested items
    static let minItemsForList = 2
    static let maxWordsForAutoListItem = 10  // heuristic for newline-separated items
}
