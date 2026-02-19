import Foundation

enum SentenceBoundaryRules {
    // MARK: - Subject Pronouns (likely start new sentences)

    static let subjectPronouns: Set<String> = [
        "i", "he", "she", "we", "they",
    ]

    // MARK: - Question Openers

    static let questionOpeners: Set<String> = [
        "how", "what", "when", "why", "where", "who",
        "can", "do", "does", "is", "are", "will", "would",
        "could", "should", "don't", "doesn't",
    ]

    // MARK: - Discourse Markers (sentence starters)

    static let discourseMarkers: Set<String> = [
        "so", "well", "now", "also", "plus", "maybe", "perhaps",
        "however", "therefore", "meanwhile", "anyway", "besides",
        "actually", "basically", "honestly", "literally",
    ]

    // MARK: - Contraction Restarters

    static let contractionRestarters: Set<String> = [
        "i'm", "i've", "i'll", "i'd",
        "it's", "that's", "there's",
        "let's",
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
    ]
}
