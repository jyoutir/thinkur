import Foundation

enum SelfCorrectionRules {
    // MARK: - High confidence phrases (almost always a correction)

    static let highConfidencePhrases: [ReplacementRule] = [
        ReplacementRule(pattern: "scratch that",       replacement: "", confidence: 1.0, category: "explicit"),
        ReplacementRule(pattern: "delete that",        replacement: "", confidence: 1.0, category: "explicit"),
        ReplacementRule(pattern: "erase that",         replacement: "", confidence: 1.0, category: "explicit"),
        ReplacementRule(pattern: "remove that",        replacement: "", confidence: 1.0, category: "explicit"),
        ReplacementRule(pattern: "undo that",          replacement: "", confidence: 1.0, category: "explicit"),
        ReplacementRule(pattern: "take that back",     replacement: "", confidence: 1.0, category: "explicit"),
        ReplacementRule(pattern: "strike that",        replacement: "", confidence: 1.0, category: "explicit"),
        ReplacementRule(pattern: "disregard that",     replacement: "", confidence: 1.0, category: "explicit"),
        ReplacementRule(pattern: "ignore that",        replacement: "", confidence: 1.0, category: "explicit"),
        ReplacementRule(pattern: "forget that",        replacement: "", confidence: 1.0, category: "explicit"),
        ReplacementRule(pattern: "never mind",         replacement: "", confidence: 1.0, category: "explicit"),
        ReplacementRule(pattern: "nevermind",          replacement: "", confidence: 1.0, category: "explicit"),
        ReplacementRule(pattern: "start over",         replacement: "", confidence: 1.0, category: "full_reset"),
        ReplacementRule(pattern: "let me start over",  replacement: "", confidence: 1.0, category: "full_reset"),
        ReplacementRule(pattern: "let me start again", replacement: "", confidence: 1.0, category: "full_reset"),
        ReplacementRule(pattern: "let me try again",   replacement: "", confidence: 1.0, category: "full_reset"),
        ReplacementRule(pattern: "let me redo that",   replacement: "", confidence: 1.0, category: "full_reset"),
        ReplacementRule(pattern: "actually no",        replacement: "", confidence: 1.0, category: "explicit"),
        ReplacementRule(pattern: "no no no",           replacement: "", confidence: 1.0, category: "explicit"),
    ]

    // MARK: - Medium confidence phrases

    static let mediumConfidencePhrases: [ReplacementRule] = [
        ReplacementRule(pattern: "no actually",          replacement: "", confidence: 0.85, category: "correction"),
        ReplacementRule(pattern: "wait no",              replacement: "", confidence: 0.85, category: "correction"),
        ReplacementRule(pattern: "no wait",              replacement: "", confidence: 0.85, category: "correction"),
        ReplacementRule(pattern: "or rather",            replacement: "", confidence: 0.85, category: "correction"),
        ReplacementRule(pattern: "or actually",          replacement: "", confidence: 0.85, category: "correction"),
        ReplacementRule(pattern: "well actually",        replacement: "", confidence: 0.85, category: "correction"),
        ReplacementRule(pattern: "let me rephrase that", replacement: "", confidence: 0.85, category: "correction"),
        ReplacementRule(pattern: "let me rephrase",      replacement: "", confidence: 0.85, category: "correction"),
        ReplacementRule(pattern: "what i meant was",     replacement: "", confidence: 0.85, category: "correction"),
        ReplacementRule(pattern: "what i meant is",      replacement: "", confidence: 0.85, category: "correction"),
        ReplacementRule(pattern: "what i mean is",       replacement: "", confidence: 0.85, category: "correction"),
        ReplacementRule(pattern: "i should say",         replacement: "", confidence: 0.85, category: "correction"),
        ReplacementRule(pattern: "i meant to say",       replacement: "", confidence: 0.85, category: "correction"),
        ReplacementRule(pattern: "sorry i meant",        replacement: "", confidence: 0.85, category: "correction"),
        ReplacementRule(pattern: "sorry i mean",         replacement: "", confidence: 0.85, category: "correction"),
        ReplacementRule(pattern: "no i meant",           replacement: "", confidence: 0.85, category: "correction"),
        ReplacementRule(pattern: "no i mean",            replacement: "", confidence: 0.85, category: "correction"),
    ]

    // MARK: - Contextual phrases (need disambiguation)

    static let contextualPhrases: [ReplacementRule] = [
        ReplacementRule(pattern: "i mean",    replacement: "", confidence: 0.5, category: "contextual"),
        ReplacementRule(pattern: "actually",  replacement: "", confidence: 0.5, category: "contextual"),
        ReplacementRule(pattern: "wait",      replacement: "", confidence: 0.5, category: "contextual"),
        ReplacementRule(pattern: "no",        replacement: "", confidence: 0.5, category: "contextual"),
        ReplacementRule(pattern: "sorry",     replacement: "", confidence: 0.5, category: "contextual"),
    ]

    // MARK: - All explicit phrases (high + medium, longest first)

    static let allExplicitPhrases: [ReplacementRule] = {
        (highConfidencePhrases + mediumConfidencePhrases).sorted { $0.pattern.count > $1.pattern.count }
    }()

    // MARK: - Full reset patterns (remove ALL preceding text)

    static let fullResetPattern = #"(?i)\b(start\s+over|let\s+me\s+start\s+(over|again)|scratch\s+all(\s+of)?\s+that|delete\s+(everything|all(\s+of)?\s+that))\b"#

    // MARK: - Scope variation patterns

    static let removeLastWordPattern = #"(?i)\b(scratch|delete|remove|undo)\s+(the\s+)?last\s+word\b"#
    static let removeLastSentencePattern = #"(?i)\b(scratch|delete|remove|undo)\s+(the\s+)?last\s+sentence\b"#

    // MARK: - "i mean" disambiguation (non-correction uses)

    static let iMeanKeepPatterns: [String] = [
        #"(?i)\bi\s+mean\s+(it|well|to)\b"#,
        #"(?i)\b(do|did|does|don't|doesn't|what\s+do)\s+.*\bi\s+mean\b"#,
        #"(?i)\bwhat\s+i\s+mean\b"#,
        #"(?i)\bknow\s+what\s+i\s+mean\b"#,
        #"(?i)\bi\s+mean\s*$"#,
        #"(?i)^i\s+mean\b"#,
    ]

    // MARK: - "actually" disambiguation (non-correction uses)

    static let actuallyKeepPatterns: [String] = [
        #"(?i)\bactually\s+(is|was|were|are|did|does|do|have|has|had|can|could|would|should|went|came|got|made|said|like|really|quite|pretty|very|works|looks|seems|feels|turns|helps|means|happens|matters|worked|looked)\b"#,
        #"(?i)\b(i|we|they|he|she|it|you)\s+actually\b"#,
        #"(?i)\b\w+\s+actually\s+\w+"#,
    ]

    // MARK: - "wait" disambiguation (non-correction uses)

    static let waitKeepPatterns: [String] = [
        #"(?i)\bwait\s+(for|here|there|until|a\s+moment|a\s+minute|a\s+second|a\s+sec|up)\b"#,
        #"(?i)\b(can|could|please|just|have\s+to|need\s+to)\s+wait\b"#,
        // Verb phrases ending in "wait" (not a correction signal)
        #"(?i)\b(should|will|would|must|might|may|shall|going\s+to|want\s+to|used\s+to|can't|cannot|won't|will\s+not)\s+wait\b"#,
        // "wait" as the last word after a verb/subject (predicate usage)
        #"(?i)\bwe\s+should\s+wait\b"#,
        #"(?i)\bwait\s*[.?!]"#,
    ]

    // MARK: - "no" disambiguation (non-correction uses)

    static let noKeepPatterns: [String] = [
        #"(?i)\bno\s+(problem|way|doubt|need|longer|more|one|matter|rush|thanks|thank|worries)\b"#,
        #"(?i)\bsaid\s+no\b"#,
        #"(?i)\bno,\s"#,
        #"(?i)^no\s+(i|we|he|she|they|it|you|the|that|this)\b"#,
        #"(?i)\bno\s+(i|we)\s+(don't|do\s+not|didn't|did\s+not|can't|cannot|won't|will\s+not|think|believe|have)\b"#,
    ]

    // MARK: - "sorry" disambiguation (non-correction uses)

    static let sorryKeepPatterns: [String] = [
        #"(?i)\bi'm\s+sorry\b"#,
        #"(?i)\bsorry\s+(about|for|to|if|that|but|i'm)\b"#,
        #"(?i)^sorry\b"#,
    ]

    // MARK: - Intentional repetitions (do NOT remove)

    static let intentionalRepetitions: Set<String> = [
        "very", "really", "so", "super", "ha", "haha",
        "bye", "knock", "go", "no", "tsk", "shh",
        "now", "there", "come", "well", "boo",
        // Spoken punctuation patterns — "dot dot dot" → "..." should NOT be collapsed
        "dot",
    ]

    // MARK: - Subject pronouns (for abandoned clause detection)

    static let subjectPronouns: Set<String> = [
        "i", "we", "he", "she", "they", "it", "you",
        "my", "our", "his", "her", "their", "its", "your",
    ]

    // MARK: - Sentence starters (for restart detection)

    static let sentenceStarters: Set<String> = [
        "the", "this", "that", "these", "those",
        "there", "here", "so", "but", "and", "well",
        "anyway", "also", "however", "meanwhile",
    ]

    // MARK: - Quoted speech detection (don't treat as correction)

    // MARK: - "never mind" disambiguation (literal vs correction)

    static let neverMindKeepPatterns: [String] = [
        #"(?i)\bnever\s+mind\s+(the|about|that|what|how|if|whether|my|your|his|her|our|their)\b"#,
    ]

    static let quotedSpeechPattern = #"(?i)\b(said|says|wrote|typed|means|meaning|called|titled|named)\s+["']?"#

    // MARK: - Structural Boundary Words (for medium-confidence corrections)

    static let structuralBoundaryWords: Set<String> = [
        "said", "says", "told", "asked", "mentioned", "reported",
        "and", "but", "or", "that", "which", "who", "when", "where",
        "because", "since", "after", "before", "while", "if", "although",
        // Linking verbs: keep "the budget is" when correcting "seventy" → "75000"
        "is", "was", "are", "were", "am", "been", "being",
        "has", "have", "had",
        // Prepositions: keep "meet me on" when correcting "tuesday" → "wednesday"
        "on", "at", "in", "to", "for", "with", "from", "of", "about",
        "into", "over", "under", "between", "through",
    ]

    static let maxCorrectionIterations = 10
}
