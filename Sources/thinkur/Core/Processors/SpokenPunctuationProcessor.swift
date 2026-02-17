import Foundation

struct SpokenPunctuationProcessor: TextProcessor {
    let name = "SpokenPunctuation"

    private static let replacements: [(pattern: String, replacement: String)] = [
        (#"\bperiod\b"#, "."),
        (#"\bfull stop\b"#, "."),
        (#"\bcomma\b"#, ","),
        (#"\bquestion mark\b"#, "?"),
        (#"\bexclamation mark\b"#, "!"),
        (#"\bexclamation point\b"#, "!"),
        (#"\bcolon\b"#, ":"),
        (#"\bsemicolon\b"#, ";"),
        (#"\bsemi colon\b"#, ";"),
        (#"\bellipsis\b"#, "..."),
        (#"\bdot dot dot\b"#, "..."),
        (#"\bdash\b"#, " — "),
        (#"\bhyphen\b"#, "-"),
        (#"\bopen quote\b"#, "\""),
        (#"\bclose quote\b"#, "\""),
        (#"\bopen paren\b"#, "("),
        (#"\bclose paren\b"#, ")"),
        (#"\bnew line\b"#, "\n"),
        (#"\bnewline\b"#, "\n"),
        (#"\bnew paragraph\b"#, "\n\n"),
    ]

    func process(_ text: String, context: ProcessingContext) -> ProcessorResult {
        var result = text

        for (pattern, replacement) in Self.replacements {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: replacement
            )
        }

        result = cleanPunctuationSpacing(result)
        return ProcessorResult(text: normalizeWhitespace(result))
    }
}
