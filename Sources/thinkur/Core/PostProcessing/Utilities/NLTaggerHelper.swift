import Foundation
import NaturalLanguage

struct NLTaggerHelper {
    // Cached tagger instances to avoid expensive allocations (50-100ms per init)
    private static let lexicalTagger = NLTagger(tagSchemes: [.lexicalClass])
    private static let nameTagger = NLTagger(tagSchemes: [.nameType])
    private static let lock = NSLock()

    static func lexicalClass(of word: String, in sentence: String, at wordIndex: Int) -> NLTag? {
        lock.lock()
        defer { lock.unlock() }

        lexicalTagger.string = sentence

        let words = sentence.split(separator: " ", omittingEmptySubsequences: true)
        guard wordIndex < words.count else { return nil }

        var charOffset = 0
        for j in 0..<wordIndex {
            charOffset += words[j].count + 1
        }

        let targetIndex = sentence.index(sentence.startIndex, offsetBy: min(charOffset, sentence.count - 1))
        return lexicalTagger.tag(at: targetIndex, unit: .word, scheme: .lexicalClass).0
    }

    static func isProperNoun(_ word: String, in sentence: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        nameTagger.string = sentence

        var found = false
        nameTagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex, unit: .word, scheme: .nameType) { tag, range in
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
        lock.lock()
        defer { lock.unlock() }

        nameTagger.string = sentence

        var result: NLTag?
        nameTagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex, unit: .word, scheme: .nameType) { tag, range in
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
