import Foundation
import NaturalLanguage

struct NLTaggerHelper {
    static func lexicalClass(of word: String, in sentence: String, at wordIndex: Int) -> NLTag? {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = sentence

        let words = sentence.split(separator: " ", omittingEmptySubsequences: true)
        guard wordIndex < words.count else { return nil }

        var charOffset = 0
        for j in 0..<wordIndex {
            charOffset += words[j].count + 1
        }

        let targetIndex = sentence.index(sentence.startIndex, offsetBy: min(charOffset, sentence.count - 1))
        return tagger.tag(at: targetIndex, unit: .word, scheme: .lexicalClass).0
    }

    static func isProperNoun(_ word: String, in sentence: String) -> Bool {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = sentence

        var found = false
        tagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if let tag, (tag == .personalName || tag == .placeName || tag == .organizationName) {
                let matched = String(sentence[range]).lowercased()
                if matched == word.lowercased() {
                    found = true
                    return false
                }
            }
            return true
        }
        return found
    }

    static func nameTag(for word: String, in sentence: String) -> NLTag? {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = sentence

        var result: NLTag?
        tagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if let tag, (tag == .personalName || tag == .placeName || tag == .organizationName) {
                let matched = String(sentence[range]).lowercased()
                if matched == word.lowercased() {
                    result = tag
                    return false
                }
            }
            return true
        }
        return result
    }
}
