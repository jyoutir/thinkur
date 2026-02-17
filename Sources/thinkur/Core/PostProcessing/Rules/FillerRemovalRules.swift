import Foundation
import NaturalLanguage

enum FillerRemovalRules {
    // MARK: - Category 1: Pure hesitation markers

    static let hesitationFillers: [ReplacementRule] = [
        ReplacementRule(pattern: "ummm",   replacement: "", confidence: 0.95, category: "hesitation"),
        ReplacementRule(pattern: "umm",    replacement: "", confidence: 0.95, category: "hesitation"),
        ReplacementRule(pattern: "um",     replacement: "", confidence: 0.95, category: "hesitation"),
        ReplacementRule(pattern: "uhhh",   replacement: "", confidence: 0.95, category: "hesitation"),
        ReplacementRule(pattern: "uhh",    replacement: "", confidence: 0.95, category: "hesitation"),
        ReplacementRule(pattern: "uh",     replacement: "", confidence: 0.95, category: "hesitation"),
        ReplacementRule(pattern: "erm",    replacement: "", confidence: 0.95, category: "hesitation"),
        ReplacementRule(pattern: "er",     replacement: "", confidence: 0.95, category: "hesitation"),
        ReplacementRule(pattern: "ahh",    replacement: "", confidence: 0.95, category: "hesitation"),
        ReplacementRule(pattern: "ah",     replacement: "", confidence: 0.95, category: "hesitation"),
        ReplacementRule(pattern: "eh",     replacement: "", confidence: 0.95, category: "hesitation"),
        ReplacementRule(pattern: "hmmm",   replacement: "", confidence: 0.95, category: "hesitation"),
        ReplacementRule(pattern: "hmm",    replacement: "", confidence: 0.95, category: "hesitation"),
        ReplacementRule(pattern: "hm",     replacement: "", confidence: 0.95, category: "hesitation"),
        ReplacementRule(pattern: "mmm",    replacement: "", confidence: 0.95, category: "hesitation"),
        ReplacementRule(pattern: "mm",     replacement: "", confidence: 0.95, category: "hesitation"),
        ReplacementRule(pattern: "mhm",    replacement: "", confidence: 0.95, category: "hesitation"),
        ReplacementRule(pattern: "uh huh", replacement: "", confidence: 0.95, category: "hesitation"),
        ReplacementRule(pattern: "mm hmm", replacement: "", confidence: 0.95, category: "hesitation"),
    ]

    // MARK: - Category 2: Discourse markers (context-dependent)

    static let discourseMarkers: [(word: String, disambiguate: Bool, confidence: Float)] = [
        ("well",        true,  0.8),
        ("so",          true,  0.8),
        ("like",        true,  0.7),
        ("okay",        true,  0.8),
        ("ok",          true,  0.8),
        ("right",       true,  0.7),
        ("anyway",      false, 0.9),
        ("anyways",     false, 0.9),
        ("basically",   false, 0.9),
        ("literally",   false, 0.9),
        ("honestly",    false, 0.9),
        ("actually",    true,  0.7),
        ("obviously",   false, 0.9),
        ("clearly",     true,  0.7),
        ("essentially", false, 0.9),
        ("apparently",  true,  0.7),
    ]

    // MARK: - Category 3: Multi-word fillers (sorted longest first)

    static let multiWordFillers: [ReplacementRule] = [
        ReplacementRule(pattern: "you know what i mean",  replacement: "", confidence: 0.95, category: "multi_word"),
        ReplacementRule(pattern: "or something like that", replacement: "", confidence: 0.9, category: "multi_word"),
        ReplacementRule(pattern: "how should i put this", replacement: "", confidence: 0.95, category: "multi_word"),
        ReplacementRule(pattern: "and things like that",  replacement: "", confidence: 0.9, category: "multi_word"),
        ReplacementRule(pattern: "at the end of the day", replacement: "", confidence: 0.7, category: "multi_word"),
        ReplacementRule(pattern: "how do i say this",     replacement: "", confidence: 0.95, category: "multi_word"),
        ReplacementRule(pattern: "you know what",         replacement: "", confidence: 0.85, category: "multi_word"),
        ReplacementRule(pattern: "what's the word",       replacement: "", confidence: 0.95, category: "multi_word"),
        ReplacementRule(pattern: "and everything",        replacement: "", confidence: 0.8, category: "multi_word"),
        ReplacementRule(pattern: "or something",          replacement: "", confidence: 0.8, category: "multi_word"),
        ReplacementRule(pattern: "or whatever",           replacement: "", confidence: 0.85, category: "multi_word"),
        ReplacementRule(pattern: "and all that",          replacement: "", confidence: 0.85, category: "multi_word"),
        ReplacementRule(pattern: "and whatnot",           replacement: "", confidence: 0.9, category: "multi_word"),
        ReplacementRule(pattern: "and things",            replacement: "", confidence: 0.7, category: "multi_word"),
        ReplacementRule(pattern: "and stuff",             replacement: "", confidence: 0.85, category: "multi_word"),
        ReplacementRule(pattern: "to be honest",          replacement: "", confidence: 0.8, category: "multi_word"),
        ReplacementRule(pattern: "to be fair",            replacement: "", confidence: 0.6, category: "multi_word"),
        ReplacementRule(pattern: "so to speak",           replacement: "", confidence: 0.9, category: "multi_word"),
        ReplacementRule(pattern: "if you will",           replacement: "", confidence: 0.9, category: "multi_word"),
        ReplacementRule(pattern: "as it were",            replacement: "", confidence: 0.9, category: "multi_word"),
        ReplacementRule(pattern: "let me think",          replacement: "", confidence: 0.9, category: "multi_word"),
        ReplacementRule(pattern: "let me see",            replacement: "", confidence: 0.8, category: "multi_word"),
        ReplacementRule(pattern: "let's see",             replacement: "", confidence: 0.8, category: "multi_word"),
        ReplacementRule(pattern: "more or less",          replacement: "", confidence: 0.6, category: "multi_word"),
        ReplacementRule(pattern: "what is it",            replacement: "", confidence: 0.6, category: "multi_word"),
        ReplacementRule(pattern: "you know",              replacement: "", confidence: 0.9, category: "multi_word"),
        ReplacementRule(pattern: "you see",               replacement: "", confidence: 0.8, category: "multi_word"),
        ReplacementRule(pattern: "i guess",               replacement: "", confidence: 0.7, category: "multi_word"),
        ReplacementRule(pattern: "i suppose",             replacement: "", confidence: 0.7, category: "multi_word"),
        ReplacementRule(pattern: "sort of",               replacement: "", confidence: 0.7, category: "multi_word"),
        ReplacementRule(pattern: "kind of",               replacement: "", confidence: 0.7, category: "multi_word"),
        ReplacementRule(pattern: "in a way",              replacement: "", confidence: 0.5, category: "multi_word"),
    ]

    // MARK: - Category 4: Verbal tics

    static let verbalTics: [ReplacementRule] = [
        ReplacementRule(pattern: "uh huh",  replacement: "", confidence: 0.9, category: "verbal_tic"),
        ReplacementRule(pattern: "mm hmm",  replacement: "", confidence: 0.9, category: "verbal_tic"),
        ReplacementRule(pattern: "nuh uh",  replacement: "", confidence: 0.9, category: "verbal_tic"),
        ReplacementRule(pattern: "uh uh",   replacement: "", confidence: 0.9, category: "verbal_tic"),
        ReplacementRule(pattern: "tsk",     replacement: "", confidence: 0.9, category: "verbal_tic"),
        ReplacementRule(pattern: "pfft",    replacement: "", confidence: 0.9, category: "verbal_tic"),
        ReplacementRule(pattern: "pff",     replacement: "", confidence: 0.9, category: "verbal_tic"),
        ReplacementRule(pattern: "psst",    replacement: "", confidence: 0.9, category: "verbal_tic"),
        ReplacementRule(pattern: "shh",     replacement: "", confidence: 0.9, category: "verbal_tic"),
        ReplacementRule(pattern: "whew",    replacement: "", confidence: 0.9, category: "verbal_tic"),
        ReplacementRule(pattern: "phew",    replacement: "", confidence: 0.9, category: "verbal_tic"),
        ReplacementRule(pattern: "ooh",     replacement: "", confidence: 0.9, category: "verbal_tic"),
        ReplacementRule(pattern: "eek",     replacement: "", confidence: 0.9, category: "verbal_tic"),
        ReplacementRule(pattern: "whoops",  replacement: "", confidence: 0.9, category: "verbal_tic"),
        ReplacementRule(pattern: "oops",    replacement: "", confidence: 0.9, category: "verbal_tic"),
    ]

    // MARK: - Disambiguation rules

    static let wellDisambiguation = DisambiguationRule(
        word: "well",
        keepPatterns: [
            #"(?i)\b(feeling|doing|is|am|are|was|were|look|looking|seem|seems|get|getting)\s+well\b"#,
            #"(?i)\bwell\s+(done|known|aware|equipped|prepared|established|organized|informed|received|suited|made|built|designed|thought|written|read|educated|trained|versed|spoken|liked|loved|deserved|earned|documented|defined|crafted|maintained|rounded)\b"#,
            #"(?i)\bas\s+well\b"#,
            #"(?i)\bmight\s+as\s+well\b"#,
            #"(?i)\boh\s+well\b"#,
            #"(?i)\bvery\s+well\b"#,
            #"(?i)\b(water|oil|wishing)\s+well\b"#,
        ],
        removePatterns: [
            #"(?i)(?:^|(?<=[.!?,;:\n]\s*))well[,]?\s+"#,
        ]
    )

    static let soDisambiguation = DisambiguationRule(
        word: "so",
        keepPatterns: [
            #"(?i)\bso\s+(good|bad|much|many|far|long|great|nice|cool|hard|fast|slow|big|small|happy|sad|tired|hungry|beautiful|important|sorry|glad|excited|proud|true|real|close|early|late|often|well)\b"#,
            #"(?i)\bso\s+that\b"#,
            #"(?i)\bso\s+as\s+to\b"#,
            #"(?i)\bso\s+long\s+as\b"#,
            #"(?i)\bif\s+so\b"#,
            #"(?i)\bor\s+so\b"#,
            #"(?i)\beven\s+so\b"#,
            #"(?i)\b\w+\s+so\s+(i|we|he|she|they|it|you|that|the)\b"#,
        ],
        removePatterns: [
            #"(?i)^so[,]?\s+"#,
            #"(?i)(?<=[.!?\n]\s*)so[,]?\s+"#,
        ]
    )

    static let okayDisambiguation = DisambiguationRule(
        word: "okay",
        keepPatterns: [
            #"(?i)\b(i'm|i\s+am|it's|it\s+is|that's|that\s+is|you're|he's|she's|we're|they're|everything\s+is|things\s+are|feeling|looks?|seems?|sounds?)\s+ok(ay)?\b"#,
            #"(?i)\bok(ay)?\s+(with|to|for|about|at|by)\b"#,
        ],
        removePatterns: [
            #"(?i)(?:^|(?<=[.!?\n]\s*))ok(ay)?[,]?\s+"#,
        ]
    )

    static let rightDisambiguation = DisambiguationRule(
        word: "right",
        keepPatterns: [
            #"(?i)\b(the|a|my|your|his|her|its|our|their)\s+right\s+(answer|way|thing|choice|decision|direction|side|hand|arm|foot|leg|eye|ear|turn|place|time|moment|move|person|word|idea|approach|method|tool|path)\b"#,
            #"(?i)\bright\s+(now|here|there|away|after|before|behind|above|below|beside|next|back|through|off|on|up|down)\b"#,
            #"(?i)\b(all|that's|you're|it's)\s+right\b"#,
            #"(?i)\bturn\s+right\b"#,
            #"(?i)\bright\s+to\s+\w+\b"#,
        ],
        removePatterns: [
            #"(?i)(?:^|(?<=[.!?\n]\s*))right[,]?\s+"#,
            #"(?i)\s+right\s*$"#,
        ]
    )

    static let likeKeepPatterns: [String] = [
        #"(?i)\b(would|do|does|did|don't|doesn't|didn't|i|you|we|they|he|she|it|who|everyone|nobody|people)\s+like\b"#,
        #"(?i)\b(look|looks|looked|looking|sound|sounds|sounded|feel|feels|felt|seem|seems|seemed|taste|tastes|tasted|smell|smells|smelled|act|acts|acted)\s+like\b"#,
        #"(?i)\bjust\s+like\b"#,
        #"(?i)\blike\s+(this|that|these|those|me|you|him|her|it|us|them|what|when|where|how)\b"#,
        #"(?i)\bsomething\s+like\b"#,
        #"(?i)\bnothing\s+like\b"#,
        #"(?i)\bmore\s+like\b"#,
    ]

    static let fillerPreceders: Set<String> = [
        "and", "but", "so", "was", "just", "it's", "its", "yeah", "oh",
        "well", "or", "then", "like", "really", "very", "been", "were",
        "is", "are", "be", "being", "basically", "honestly",
    ]

    // MARK: - "sort of" / "kind of" disambiguation

    static let sortKindOfKeepPattern = #"(?i)\b(what|which|every|any|some|no|this|that|these|those|a|an|the|each)\s+(sort|kind)\s+of\b"#

    // MARK: - Exclamatory usage (preserve "ah"/"oh" as exclamation)

    static let exclamatoryPattern = #"(?i)(?:^|(?<=[.!?\n]\s*))(ah|oh)\s*[,!]"#
}
