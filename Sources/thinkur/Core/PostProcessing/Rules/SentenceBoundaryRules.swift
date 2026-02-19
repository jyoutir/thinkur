import Foundation

enum SentenceBoundaryRules {
    // MARK: - Subject Pronouns (likely start new sentences)
    // Very conservative: only standalone "I" and "we"/"they" (which rarely follow nouns)

    static let subjectPronouns: Set<String> = [
        "i",
    ]

    // MARK: - Question Openers
    // Removed entirely — words like "is", "can", "do" cause too many false positives mid-sentence

    static let questionOpeners: Set<String> = []

    // MARK: - Discourse Markers (sentence starters)
    // Only very high-confidence markers that rarely appear mid-sentence

    static let discourseMarkers: Set<String> = [
        "so", "however", "therefore", "meanwhile",
    ]

    // MARK: - Contraction Restarters

    static let contractionRestarters: Set<String> = [
        "i'm", "i've", "i'll", "i'd",
        "let's",
    ]

    // MARK: - Greeting/Sentiment Starters

    static let greetingStarters: Set<String> = [
        "thank", "thanks", "please",
    ]

    // MARK: - Joining Words (don't break before these contexts)

    static let joiningWords: Set<String> = [
        "and", "but", "or", "nor", "yet", "because", "since",
        "while", "although", "though", "unless", "until",
        "that", "which", "who", "whom", "whose",
        "whether", "than", "as", "before", "after", "if",
    ]

    // MARK: - Incomplete Enders (don't break after these)

    static let incompleteEnders: Set<String> = [
        "a", "an", "the", "to", "of", "in", "at", "by", "for",
        "with", "from", "on", "about", "into", "over", "under",
        "is", "are", "was", "were", "be", "been", "being",
        "has", "have", "had", "do", "does", "did",
        "will", "would", "shall", "should", "can", "could",
        "may", "might", "must", "not", "very", "really",
        "pretty", "quite", "just", "also", "still", "even",
        "so", "too", "and", "but", "or",
        // Temporal adverbs — don't break sentence before "I" after these
        "today", "yesterday", "tomorrow", "now", "then", "here",
        "already", "soon", "later", "currently", "recently",
        "usually", "always", "often", "sometimes", "never",
        "again", "still", "yet",
    ]
}
