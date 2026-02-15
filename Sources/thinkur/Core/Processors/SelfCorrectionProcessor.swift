import Foundation

struct SelfCorrectionProcessor: TextProcessor {
    let name = "SelfCorrection"

    private static let correctionPhrases = [
        "no actually",
        "actually no",
        "scratch that",
        "never mind",
        "nevermind",
        "wait no",
        "no wait",
        "i mean",
        "sorry i meant",
        "let me rephrase",
        "start over",
    ]

    func process(_ text: String, context: ProcessingContext) -> String {
        var result = text
        let lower = result.lowercased()

        for phrase in Self.correctionPhrases {
            guard let range = lower.range(of: phrase) else { continue }
            let beforeCorrection = lower[lower.startIndex..<range.lowerBound]
            let lastSentenceBreak = beforeCorrection.lastIndex(where: { $0 == "." || $0 == "!" || $0 == "?" || $0 == "\n" })
            let clauseStart = lastSentenceBreak.map { beforeCorrection.index(after: $0) } ?? beforeCorrection.startIndex

            let removeStart = result.index(result.startIndex, offsetBy: beforeCorrection.distance(from: beforeCorrection.startIndex, to: clauseStart))
            let afterPhrase = result[range.upperBound...]
            let keepText = afterPhrase.drop(while: { $0 == " " || $0 == "," })
            result = String(result[result.startIndex..<removeStart]) + keepText
            break
        }

        return result.trimmingCharacters(in: .whitespaces)
    }
}
