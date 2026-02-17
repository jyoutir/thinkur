import Foundation

struct NumberConversionProcessor: TextProcessor {
    let name = "NumberConversion"

    private static let ones: [String: Int] = [
        "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4,
        "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9,
        "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13,
        "fourteen": 14, "fifteen": 15, "sixteen": 16, "seventeen": 17,
        "eighteen": 18, "nineteen": 19,
    ]

    private static let tens: [String: Int] = [
        "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50,
        "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90,
    ]

    private static let magnitudes: [String: Int] = [
        "hundred": 100,
        "thousand": 1_000,
        "million": 1_000_000,
        "billion": 1_000_000_000,
    ]

    private static var allNumberWords: Set<String> {
        var words = Set(ones.keys)
        words.formUnion(tens.keys)
        words.formUnion(magnitudes.keys)
        words.insert("and")
        return words
    }

    func process(_ text: String, context: ProcessingContext) -> ProcessorResult {
        let words = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        var result: [String] = []
        var i = 0

        while i < words.count {
            let lower = words[i].lowercased()

            if Self.ones[lower] != nil || Self.tens[lower] != nil {
                // Start collecting number words
                var numberWords: [String] = []
                var j = i
                while j < words.count {
                    let w = words[j].lowercased()
                    if Self.allNumberWords.contains(w) {
                        // "and" only valid between number words
                        if w == "and" {
                            if j + 1 < words.count && Self.allNumberWords.contains(words[j + 1].lowercased()) && words[j + 1].lowercased() != "and" {
                                numberWords.append(w)
                            } else {
                                break
                            }
                        } else {
                            numberWords.append(w)
                        }
                        j += 1
                    } else {
                        break
                    }
                }

                if numberWords.count >= 2 || (numberWords.count == 1 && Self.ones[numberWords[0].lowercased()] != nil && (Self.ones[numberWords[0].lowercased()]! >= 10 || Self.magnitudes.keys.contains(where: { numberWords.contains($0) }))) {
                    // Convert to number only if there are multiple words (to avoid converting single "one", "two", etc.)
                    if numberWords.count >= 2 {
                        let value = parseNumber(numberWords.map { $0.lowercased() })
                        result.append(String(value))
                        i = j
                        continue
                    }
                }

                result.append(words[i])
                i += 1
            } else {
                result.append(words[i])
                i += 1
            }
        }

        return ProcessorResult(text: result.joined(separator: " "))
    }

    private func parseNumber(_ words: [String]) -> Int {
        let filtered = words.filter { $0 != "and" }
        var total = 0
        var current = 0

        for word in filtered {
            if let value = Self.ones[word] {
                current += value
            } else if let value = Self.tens[word] {
                current += value
            } else if word == "hundred" {
                current = (current == 0 ? 1 : current) * 100
            } else if let magnitude = Self.magnitudes[word], magnitude >= 1000 {
                current = (current == 0 ? 1 : current) * magnitude
                total += current
                current = 0
            }
        }

        return total + current
    }
}
