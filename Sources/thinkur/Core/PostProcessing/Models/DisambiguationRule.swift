import Foundation
import NaturalLanguage

struct DisambiguationRule {
    let word: String
    let keepPatterns: [String]
    let removePatterns: [String]
    let usePOSTagging: Bool
    let keepPOSTags: Set<NLTag>

    init(
        word: String,
        keepPatterns: [String] = [],
        removePatterns: [String] = [],
        usePOSTagging: Bool = false,
        keepPOSTags: Set<NLTag> = []
    ) {
        self.word = word
        self.keepPatterns = keepPatterns
        self.removePatterns = removePatterns
        self.usePOSTagging = usePOSTagging
        self.keepPOSTags = keepPOSTags
    }
}
