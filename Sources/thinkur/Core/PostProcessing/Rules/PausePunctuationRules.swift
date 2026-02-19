import Foundation

enum PausePunctuationRules {
    // MARK: - Question Starters

    static let questionStarters: Set<String> = [
        "who", "what", "where", "when", "why", "how",
        "is", "are", "was", "were", "will", "would",
        "can", "could", "should", "do", "does", "did",
        "have", "has", "had", "shall", "may", "might",
        "isn't", "aren't", "wasn't", "weren't", "won't",
        "wouldn't", "can't", "couldn't", "shouldn't",
        "doesn't", "don't", "didn't", "hasn't", "haven't",
    ]

    // MARK: - Continuation Words (don't insert period before these)

    static let continuationWords: Set<String> = [
        "and", "but", "or", "nor", "yet", "so", "because", "since",
        "while", "although", "though", "unless", "until", "when",
        "where", "if", "that", "which", "who", "whom", "whose",
        "whether", "than", "as", "before", "after",
    ]

    // MARK: - Incomplete Enders (don't insert period after these)

    static let incompleteEnders: Set<String> = [
        "a", "an", "the", "to", "of", "in", "at", "by", "for",
        "with", "from", "on", "about", "into", "over", "under",
        "through", "between", "among", "within", "without",
        "toward", "towards", "upon", "against", "along",
        "and", "but", "or", "nor", "yet", "so",
        "is", "are", "was", "were", "be", "been", "being",
        "has", "have", "had", "do", "does", "did",
        "will", "would", "shall", "should", "can", "could",
        "may", "might", "must",
        "not", "very", "really", "quite", "rather", "just",
    ]

    // MARK: - No Comma After (don't insert comma after these)

    static let noCommaAfter: Set<String> = [
        "a", "an", "the", "this", "that", "these", "those",
        "my", "your", "his", "her", "its", "our", "their",
        "is", "are", "was", "were", "be", "been", "being",
        "very", "really", "quite", "rather", "too", "so",
        "not", "no", "don't", "doesn't", "didn't", "won't",
        "can't", "couldn't", "shouldn't", "wouldn't",
    ]

    // MARK: - Exclamatory Starters

    static let exclamatoryStarters: Set<String> = [
        "wow", "whoa", "yay", "hooray", "hurray", "hurrah",
        "congratulations", "congrats",
        "yes", "absolutely", "definitely",
        "incredible", "unbelievable", "amazing", "awesome",
        "fantastic", "wonderful", "brilliant", "perfect",
        "terrible", "horrible", "awful", "disgusting",
    ]

    static let exclamatoryMultiWord: [String] = [
        "oh my god", "oh my gosh", "oh no", "oh wow",
        "holy cow", "holy moly", "holy smokes",
        "no way", "get out", "shut up",
    ]

    // MARK: - Tag Question Pattern

    static let tagQuestionPattern =
        #"(?i)\b(isn't|aren't|wasn't|weren't|won't|wouldn't|can't|couldn't|shouldn't|doesn't|don't|didn't|hasn't|haven't|hadn't)\s+(it|he|she|they|we|you|i|that|this)\s*[.]$"#

    // MARK: - Double Punctuation Cleanup

    static let doublePunctuationPatterns: [(pattern: String, replacement: String)] = [
        (#"(?<!\.)([.!?])\s*[.,](?!\.)"#, "$1"),  // sentence-ender absorbs following comma/period (not within "...")
        (#",\s*,"#,                         ","),   // collapse double commas
        (#"\s+([.!?,;:])"#,                "$1"),  // remove space before punctuation
    ]

    // MARK: - Confidence Levels

    static let highGapConfidence: Float = 0.95    // gap > 3x sentence threshold
    static let sentenceConfidence: Float = 0.8     // gap at sentence threshold
    static let clauseConfidence: Float = 0.7       // gap at clause threshold
    static let questionConfidence: Float = 0.85    // question word detected
    static let tagQuestionConfidence: Float = 0.75
    static let exclamationConfidence: Float = 0.6

    // MARK: - Max words for exclamation detection

    static let maxExclamationWords = 8
}
