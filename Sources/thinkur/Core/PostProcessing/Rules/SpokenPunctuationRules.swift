import Foundation

enum SpokenPunctuationRules {
    // MARK: - Category 1: Sentence-ending punctuation

    static let sentenceEnding: [ReplacementRule] = [
        ReplacementRule(pattern: #"\bthree\s+dots\b"#,            replacement: "...", confidence: 1.0, isRegex: true, category: "sentence_ending"),
        ReplacementRule(pattern: #"\bdot\s+dot\s+dot\b"#,         replacement: "...", confidence: 1.0, isRegex: true, category: "sentence_ending"),
        ReplacementRule(pattern: #"\bellipsis\b"#,                 replacement: "...", confidence: 1.0, isRegex: true, category: "sentence_ending"),
        ReplacementRule(pattern: #"\bfull\s+stop\b"#,             replacement: ".",   confidence: 1.0, isRegex: true, category: "sentence_ending"),
        ReplacementRule(pattern: #"\bexclamation\s+point\b"#,     replacement: "!",   confidence: 1.0, isRegex: true, category: "sentence_ending"),
        ReplacementRule(pattern: #"\bexclamation\s+mark\b"#,      replacement: "!",   confidence: 1.0, isRegex: true, category: "sentence_ending"),
        ReplacementRule(pattern: #"\bquestion\s+mark\b"#,         replacement: "?",   confidence: 1.0, isRegex: true, category: "sentence_ending"),
        ReplacementRule(pattern: #"\bperiod\b"#,                   replacement: ".",   confidence: 1.0, isRegex: true, category: "sentence_ending"),
        ReplacementRule(pattern: #"\bbang\b"#,                     replacement: "!",   confidence: 1.0, isRegex: true, category: "sentence_ending"),
    ]

    // MARK: - Category 2: Mid-sentence punctuation

    static let midSentence: [ReplacementRule] = [
        ReplacementRule(pattern: #"\bforward\s+slash\b"#,  replacement: "/",   confidence: 1.0, isRegex: true, category: "mid_sentence"),
        ReplacementRule(pattern: #"\bback\s*slash\b"#,     replacement: "\\",  confidence: 1.0, isRegex: true, category: "mid_sentence"),
        ReplacementRule(pattern: #"\bsemi\s*colon\b"#,     replacement: ";",   confidence: 1.0, isRegex: true, category: "mid_sentence"),
        ReplacementRule(pattern: #"\bem\s+dash\b"#,        replacement: " — ", confidence: 1.0, isRegex: true, category: "mid_sentence"),
        ReplacementRule(pattern: #"\ben\s+dash\b"#,        replacement: " – ", confidence: 1.0, isRegex: true, category: "mid_sentence"),
        ReplacementRule(pattern: #"\bsemicolon\b"#,        replacement: ";",   confidence: 1.0, isRegex: true, category: "mid_sentence"),
        ReplacementRule(pattern: #"\bcomma\b"#,            replacement: ",",   confidence: 1.0, isRegex: true, category: "mid_sentence"),
        ReplacementRule(pattern: #"\bcolon\b"#,            replacement: ":",   confidence: 1.0, isRegex: true, category: "mid_sentence"),
        ReplacementRule(pattern: #"\bdash\b"#,             replacement: " — ", confidence: 1.0, isRegex: true, category: "mid_sentence"),
        ReplacementRule(pattern: #"\bhyphen\b"#,           replacement: "-",   confidence: 1.0, isRegex: true, category: "mid_sentence"),
        ReplacementRule(pattern: #"\bslash\b"#,            replacement: "/",   confidence: 1.0, isRegex: true, category: "mid_sentence"),
        ReplacementRule(pattern: #"\bpipe\b"#,             replacement: " | ", confidence: 1.0, isRegex: true, category: "mid_sentence"),
    ]

    // MARK: - Category 3: Paired delimiters

    static let pairedDelimiters: [ReplacementRule] = [
        // Quotes
        ReplacementRule(pattern: #"\b(open|begin|start)\s+quote\b"#,  replacement: "\"", confidence: 1.0, isRegex: true, category: "delimiter"),
        ReplacementRule(pattern: #"\b(close|end)\s+quote\b"#,        replacement: "\"", confidence: 1.0, isRegex: true, category: "delimiter"),
        ReplacementRule(pattern: #"\bunquote\b"#,                     replacement: "\"", confidence: 1.0, isRegex: true, category: "delimiter"),
        ReplacementRule(pattern: #"\bopen\s+single\s+quote\b"#,      replacement: "'",  confidence: 1.0, isRegex: true, category: "delimiter"),
        ReplacementRule(pattern: #"\bclose\s+single\s+quote\b"#,     replacement: "'",  confidence: 1.0, isRegex: true, category: "delimiter"),
        ReplacementRule(pattern: #"\bsingle\s+quote\b"#,             replacement: "'",  confidence: 1.0, isRegex: true, category: "delimiter"),
        // Parentheses
        ReplacementRule(pattern: #"\b(open|left)\s+parenthesis\b"#,   replacement: "(", confidence: 1.0, isRegex: true, category: "delimiter"),
        ReplacementRule(pattern: #"\b(close|right)\s+parenthesis\b"#, replacement: ")", confidence: 1.0, isRegex: true, category: "delimiter"),
        ReplacementRule(pattern: #"\b(open|left)\s+parentheses\b"#,   replacement: "(", confidence: 1.0, isRegex: true, category: "delimiter"),
        ReplacementRule(pattern: #"\b(close|right)\s+parentheses\b"#, replacement: ")", confidence: 1.0, isRegex: true, category: "delimiter"),
        ReplacementRule(pattern: #"\b(open|left)\s+paren\b"#,        replacement: "(", confidence: 1.0, isRegex: true, category: "delimiter"),
        ReplacementRule(pattern: #"\b(close|right)\s+paren\b"#,      replacement: ")", confidence: 1.0, isRegex: true, category: "delimiter"),
        // Brackets
        ReplacementRule(pattern: #"\b(open|left)\s+brackets?\b"#,    replacement: "[", confidence: 1.0, isRegex: true, category: "delimiter"),
        ReplacementRule(pattern: #"\b(close|right)\s+brackets?\b"#,  replacement: "]", confidence: 1.0, isRegex: true, category: "delimiter"),
        // Braces
        ReplacementRule(pattern: #"\b(open|left)\s+(brace|curly(\s+brace)?)\b"#,  replacement: "{", confidence: 1.0, isRegex: true, category: "delimiter"),
        ReplacementRule(pattern: #"\b(close|right)\s+(brace|curly(\s+brace)?)\b"#, replacement: "}", confidence: 1.0, isRegex: true, category: "delimiter"),
        // Angle brackets
        ReplacementRule(pattern: #"\b(open|left)\s+angle(\s+bracket)?\b"#,  replacement: "<", confidence: 1.0, isRegex: true, category: "delimiter"),
        ReplacementRule(pattern: #"\b(close|right)\s+angle(\s+bracket)?\b"#, replacement: ">", confidence: 1.0, isRegex: true, category: "delimiter"),
    ]

    // MARK: - Category 4: Special characters

    static let specialCharacters: [ReplacementRule] = [
        ReplacementRule(pattern: #"\bat\s+(sign|symbol)\b"#,         replacement: "@", confidence: 1.0, isRegex: true, category: "special"),
        ReplacementRule(pattern: #"\b(hash\s*tag|hash\s+sign|number\s+sign)\b"#, replacement: "#", confidence: 1.0, isRegex: true, category: "special"),
        ReplacementRule(pattern: #"\b(ampersand|and\s+sign)\b"#,     replacement: "&", confidence: 1.0, isRegex: true, category: "special"),
        ReplacementRule(pattern: #"\basterisk\b"#,                    replacement: "*", confidence: 1.0, isRegex: true, category: "special"),
        ReplacementRule(pattern: #"\bdollar\s+sign\b"#,              replacement: "$", confidence: 1.0, isRegex: true, category: "special"),
        ReplacementRule(pattern: #"\b(caret)\b"#,                     replacement: "^", confidence: 1.0, isRegex: true, category: "special"),
        ReplacementRule(pattern: #"\btilde\b"#,                       replacement: "~", confidence: 1.0, isRegex: true, category: "special"),
        ReplacementRule(pattern: #"\bunderscore\b"#,                  replacement: "_", confidence: 1.0, isRegex: true, category: "special"),
        ReplacementRule(pattern: #"\bcopyright\s+(sign|symbol)\b"#,  replacement: "\u{00A9}", confidence: 1.0, isRegex: true, category: "special"),
        ReplacementRule(pattern: #"\bregistered\s+trademark\b"#,     replacement: "\u{00AE}", confidence: 1.0, isRegex: true, category: "special"),
        ReplacementRule(pattern: #"\btrademark\s+sign\b"#,           replacement: "\u{2122}", confidence: 1.0, isRegex: true, category: "special"),
        ReplacementRule(pattern: #"\bdegree\s+sign\b"#,              replacement: "\u{00B0}", confidence: 1.0, isRegex: true, category: "special"),
        ReplacementRule(pattern: #"\bbullet\s+point\b"#,             replacement: "\u{2022}", confidence: 1.0, isRegex: true, category: "special"),
    ]

    // MARK: - Category 5: Formatting commands

    static let formattingCommands: [ReplacementRule] = [
        ReplacementRule(pattern: #"\bnew\s+paragraph\b"#,   replacement: "\n\n", confidence: 1.0, isRegex: true, category: "formatting"),
        ReplacementRule(pattern: #"\bnext\s+paragraph\b"#,   replacement: "\n\n", confidence: 1.0, isRegex: true, category: "formatting"),
        ReplacementRule(pattern: #"\bnew\s*line\b"#,         replacement: "\n",   confidence: 1.0, isRegex: true, category: "formatting"),
        ReplacementRule(pattern: #"\btab\s+key\b"#,          replacement: "\t",   confidence: 1.0, isRegex: true, category: "formatting"),
        ReplacementRule(pattern: #"\btab\b"#,                replacement: "\t",   confidence: 1.0, isRegex: true, category: "formatting"),
    ]

    // MARK: - All rules combined (longest patterns first)

    static let allRules: [ReplacementRule] = {
        (formattingCommands + sentenceEnding + midSentence + pairedDelimiters + specialCharacters)
            .sorted { $0.pattern.count > $1.pattern.count }
    }()

    // MARK: - Disambiguation

    static let periodKeepPatterns: [String] = [
        #"(?i)\b(a|an|the|this|that|each|every|some|long|short|brief|extended|trial|waiting|class|grace|cool|warm|cooling|warming|transition|recovery|probation)\s+period\b"#,
        #"(?i)\bperiod\s+(of|in|for|during|between|from|until|after|before)\b"#,
        #"(?i)\b\w+an\s+period\b"#,
    ]

    static let dashKeepPatterns: [String] = [
        #"(?i)\b(to|need\s+to|have\s+to|got\s+to|going\s+to|want\s+to|had\s+to)\s+dash\b"#,
        #"(?i)\bdash\s+(to|for|off|out|away|through|across|around|back|home|inside|outside)\b"#,
        #"(?i)\bmad\s+dash\b"#,
        #"(?i)\b(a|the|quick|short|long|fifty|hundred)\s+yard\s+dash\b"#,
    ]

    static let colonKeepPatterns: [String] = [
        #"(?i)\b(my|your|his|her|the|a|an|healthy|inflamed|irritable)\s+colon\b"#,
        #"(?i)\bcolon\s+(cancer|surgery|health|polyp|polyps|cleanse|screening|exam|infection|inflammation|disease)\b"#,
    ]

    static let dotKeepPatterns: [String] = [
        #"(?i)\b(a|an|the|this|that|each|every|some|any|no|polka)\s+dots?\b"#,
        #"(?i)\bdots\b"#,
    ]

    static let starKeepPatterns: [String] = [
        #"(?i)\b(movie|rock|pop|all|five|four|three|two|one|super|gold|rising|north|morning|evening|shooting|lucky|lone|bright|shining|fallen|dark)\s+star\b"#,
        #"(?i)\bstars?\b(?!\s+(character|symbol|sign))"#,
    ]
}
