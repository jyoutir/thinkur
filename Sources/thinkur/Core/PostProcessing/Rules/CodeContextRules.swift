import Foundation

enum CodeContextRules {
    // MARK: - Category 1: Casing Command Patterns

    static let casingCommands: [ReplacementRule] = [
        ReplacementRule(pattern: #"\b(camel\s*case|camel)\s+"#,
                       replacement: "camelCase", confidence: 1.0, isRegex: true, category: "casing"),
        ReplacementRule(pattern: #"\b(pascal\s*case|pascal|class\s+name|type\s+name|struct\s+name)\s+"#,
                       replacement: "pascalCase", confidence: 1.0, isRegex: true, category: "casing"),
        ReplacementRule(pattern: #"\b(snake\s*case|snake)\s+"#,
                       replacement: "snakeCase", confidence: 1.0, isRegex: true, category: "casing"),
        ReplacementRule(pattern: #"\b(constant|screaming\s*snake|upper\s*snake|all\s*caps\s*snake)\s+"#,
                       replacement: "screamingSnakeCase", confidence: 1.0, isRegex: true, category: "casing"),
        ReplacementRule(pattern: #"\b(kebab\s*case|kebab|dash\s*case)\s+"#,
                       replacement: "kebabCase", confidence: 1.0, isRegex: true, category: "casing"),
        ReplacementRule(pattern: #"\b(dot\s*case|dot\s+separated)\s+"#,
                       replacement: "dotCase", confidence: 1.0, isRegex: true, category: "casing"),
    ]

    // MARK: - Category 2: Operators (longest patterns first)

    static let operators: [ReplacementRule] = [
        // Multi-word comparison (longest first)
        ReplacementRule(pattern: #"\bless\s+than\s+or\s+equal\s+to\b"#,     replacement: " <= ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bless\s+than\s+or\s+equal\b"#,          replacement: " <= ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bgreater\s+than\s+or\s+equal\s+to\b"#,  replacement: " >= ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bgreater\s+than\s+or\s+equal\b"#,       replacement: " >= ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bis\s+not\s+equal\s+to\b"#,             replacement: " != ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bis\s+not\s+equal\b"#,                   replacement: " != ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bis\s+equal\s+to\b"#,                    replacement: " == ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bnot\s+equal\s+to\b"#,                   replacement: " != ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bnot\s+equal\b"#,                        replacement: " != ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bequal\s+to\b"#,                         replacement: " == ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bstrict\s+not\s+equal\b"#,              replacement: " !== ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\btriple\s+equals\b"#,                    replacement: " === ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bstrict\s+equals\b"#,                    replacement: " === ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bdouble\s+equals\b"#,                    replacement: " == ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bequals\s+equals\b"#,                    replacement: " == ", confidence: 1.0, isRegex: true, category: "operator"),
        // Assignment compound
        ReplacementRule(pattern: #"\bplus\s+equals\b"#,                      replacement: " += ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\badd\s+assign\b"#,                       replacement: " += ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bminus\s+equals\b"#,                     replacement: " -= ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bsubtract\s+assign\b"#,                  replacement: " -= ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\btimes\s+equals\b"#,                     replacement: " *= ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bmultiply\s+assign\b"#,                  replacement: " *= ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bdivide\s+equals\b"#,                    replacement: " /= ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bdivide\s+assign\b"#,                    replacement: " /= ", confidence: 1.0, isRegex: true, category: "operator"),
        // Comparison (simple)
        ReplacementRule(pattern: #"\bless\s+than\b"#,                        replacement: " < ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bgreater\s+than\b"#,                     replacement: " > ", confidence: 1.0, isRegex: true, category: "operator"),
        // Logical
        ReplacementRule(pattern: #"\blogical\s+and\b"#,                      replacement: " && ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bdouble\s+ampersand\b"#,                 replacement: " && ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\blogical\s+or\b"#,                       replacement: " || ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bdouble\s+pipe\b"#,                      replacement: " || ", confidence: 1.0, isRegex: true, category: "operator"),
        // Special operators
        ReplacementRule(pattern: #"\bfat\s+arrow\b"#,                        replacement: " => ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\barrow\s+function\b"#,                   replacement: " => ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bthin\s+arrow\b"#,                       replacement: " -> ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\breturn\s+arrow\b"#,                     replacement: " -> ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bnil\s+coalescing\b"#,                   replacement: " ?? ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bdouble\s+question\s*mark\b"#,           replacement: " ?? ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\boptional\s+chaining\b"#,                replacement: "?.", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bquestion\s*mark\s+dot\b"#,              replacement: "?.", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bspread\s+operator\b"#,                  replacement: "...", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bscope\s+resolution\b"#,                 replacement: "::", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bdouble\s+colon\b"#,                     replacement: "::", confidence: 1.0, isRegex: true, category: "operator"),
        // Bitwise
        ReplacementRule(pattern: #"\bbitwise\s+and\b"#,                      replacement: " & ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bsingle\s+ampersand\b"#,                 replacement: " & ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bbitwise\s+or\b"#,                       replacement: " | ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bsingle\s+pipe\b"#,                      replacement: " | ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bbitwise\s+xor\b"#,                      replacement: " ^ ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bbitwise\s+not\b"#,                      replacement: "~", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bleft\s+shift\b"#,                       replacement: " << ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bshift\s+left\b"#,                       replacement: " << ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bright\s+shift\b"#,                      replacement: " >> ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bshift\s+right\b"#,                      replacement: " >> ", confidence: 1.0, isRegex: true, category: "operator"),
        // Arithmetic (single-word)
        ReplacementRule(pattern: #"\bdivided\s+by\b"#,                       replacement: " / ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bto\s+the\s+power\s+of\b"#,             replacement: " ** ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bplus\s+sign\b"#,                        replacement: " + ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bminus\s+sign\b"#,                       replacement: " - ", confidence: 1.0, isRegex: true, category: "operator"),
        // Single-word operators (most ambiguous — process last)
        ReplacementRule(pattern: #"\bequals\b"#,                             replacement: " = ", confidence: 0.9, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bplus\b"#,                               replacement: " + ", confidence: 0.9, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bminus\b"#,                              replacement: " - ", confidence: 0.9, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\btimes\b"#,                              replacement: " * ", confidence: 0.9, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bmultiply\b"#,                           replacement: " * ", confidence: 0.9, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bdivide\b"#,                             replacement: " / ", confidence: 0.9, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bmodulo\b"#,                             replacement: " % ", confidence: 1.0, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\bmod\b"#,                                replacement: " % ", confidence: 0.8, isRegex: true, category: "operator"),
        ReplacementRule(pattern: #"\breturns\b"#,                            replacement: " -> ", confidence: 0.8, isRegex: true, category: "operator"),
    ]

    // MARK: - Category 3: Mode Detection Patterns

    static let commentModePatterns: [ReplacementRule] = [
        ReplacementRule(pattern: #"\b(doc\s+comment|documentation\s+comment)\s+"#,
                       replacement: "/// ", confidence: 1.0, isRegex: true, category: "comment"),
        ReplacementRule(pattern: #"\b(line\s+)?comment\s+"#,
                       replacement: "// ", confidence: 1.0, isRegex: true, category: "comment"),
        ReplacementRule(pattern: #"\b(todo|fixme|hack|note|warning)\s+"#,
                       replacement: "annotation", confidence: 1.0, isRegex: true, category: "comment"),
    ]

    static let blockCommentPattern =
        #"(?i)\bblock\s+comment\s+(start|begin)\s+(.+)\s+block\s+comment\s+(end|stop)"#

    static let stringModePatterns: [ReplacementRule] = [
        ReplacementRule(pattern: #"\b(string\s+literal|string)\s+"#,
                       replacement: "\"", confidence: 1.0, isRegex: true, category: "string"),
    ]

    // MARK: - Category 4: Property Access Patterns

    static let propertyAccessPattern = #"(?i)\b(\w+)\s+dot\s+(\w+(?:\s+\w+)*)"#

    // MARK: - Category 5: Code Keywords

    static let swiftKeywords: Set<String> = [
        "func", "var", "let", "if", "else", "for", "while",
        "return", "import", "class", "struct", "enum", "protocol",
        "switch", "case", "default", "break", "continue",
        "try", "catch", "throw", "throws", "async", "await",
        "guard", "defer", "nil", "true", "false", "self", "super",
        "print", "where", "in", "as", "is", "init", "deinit",
        "static", "private", "public", "internal", "open",
        "override", "mutating", "typealias", "associatedtype",
        "extension", "subscript", "convenience", "required",
        "weak", "unowned", "lazy", "final", "inout",
    ]

    // MARK: - Type Keyword Mappings (spoken → Swift type)

    static let typeKeywords: [String: String] = [
        "string": "String",
        "integer": "Int",
        "int": "Int",
        "boolean": "Bool",
        "bool": "Bool",
        "double": "Double",
        "float": "Float",
        "array": "Array",
        "dictionary": "Dictionary",
        "optional": "Optional",
        "void": "Void",
        "any": "Any",
    ]

    // MARK: - Comment Annotation Keywords

    static let annotationKeywords: [String: String] = [
        "todo": "TODO",
        "fixme": "FIXME",
        "hack": "HACK",
        "note": "NOTE",
        "warning": "WARNING",
    ]
}
