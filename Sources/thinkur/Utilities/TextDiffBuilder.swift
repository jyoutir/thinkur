import SwiftUI

enum TextDiffBuilder {
    /// Builds an `AttributedString` showing removed words as faded strikethrough
    /// inline with the clean processed text.
    static func buildGhostDiff(raw: String, processed: String) -> AttributedString {
        let rawWords = raw.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        let processedWords = processed.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        let merged = mergeWithGhosts(raw: rawWords, processed: processedWords)

        var result = AttributedString()
        var isFirst = true
        for (word, isRemoved) in merged {
            if !isFirst {
                result.append(AttributedString(" "))
            }
            isFirst = false

            var attr = AttributedString(word)
            if isRemoved {
                attr.strikethroughStyle = .single
                attr.foregroundColor = .tertiaryLabelColor
            }
            result.append(attr)
        }

        return result
    }

    /// Merges raw and processed word arrays into a single sequence,
    /// marking removed words as ghosts and keeping shared/inserted words as normal.
    private static func mergeWithGhosts(raw: [String], processed: [String]) -> [(String, Bool)] {
        let diff = processed.difference(from: raw)

        var removedOffsets = Set<Int>()
        var insertions = [(offset: Int, element: String)]()

        for change in diff {
            switch change {
            case .remove(let offset, _, _):
                removedOffsets.insert(offset)
            case .insert(let offset, let element, _):
                insertions.append((offset, element))
            }
        }
        insertions.sort { $0.offset < $1.offset }

        // Map each kept raw word to its position in the processed sequence
        var rawToProcessed = [Int: Int]()
        var pIdx = 0
        let insertSet = Set(insertions.map(\.offset))
        for rIdx in 0..<raw.count {
            if removedOffsets.contains(rIdx) { continue }
            while insertSet.contains(pIdx) { pIdx += 1 }
            rawToProcessed[rIdx] = pIdx
            pIdx += 1
        }

        // Build a merged list with removed words placed just before the next kept word
        var slots = [(position: Double, word: String, isRemoved: Bool)]()

        for rIdx in 0..<raw.count {
            if removedOffsets.contains(rIdx) {
                var nextKept: Int?
                for j in (rIdx + 1)..<raw.count {
                    if let p = rawToProcessed[j] {
                        nextKept = p
                        break
                    }
                }
                let pos: Double
                if let nk = nextKept {
                    pos = Double(nk) - 0.5 + Double(rIdx) * 0.001
                } else if let prevKept = rawToProcessed.values.max() {
                    pos = Double(prevKept) + 0.5 + Double(rIdx) * 0.001
                } else {
                    pos = Double(rIdx) * 0.001
                }
                slots.append((pos, raw[rIdx], true))
            } else if let p = rawToProcessed[rIdx] {
                slots.append((Double(p), raw[rIdx], false))
            }
        }

        for ins in insertions {
            slots.append((Double(ins.offset), ins.element, false))
        }

        slots.sort { $0.position < $1.position }
        return slots.map { ($0.word, $0.isRemoved) }
    }
}
