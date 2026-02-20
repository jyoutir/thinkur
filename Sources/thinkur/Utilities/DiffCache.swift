import SwiftUI

@MainActor
final class DiffCache {
    static let shared = DiffCache()

    private var cache: [String: AttributedString] = [:]
    private let maxSize = 500

    private init() {}

    func getDiff(raw: String, processed: String) -> AttributedString {
        let key = "\(raw.hashValue):\(processed.hashValue)"

        if let cached = cache[key] {
            return cached
        }

        let diff = TextDiffBuilder.buildGhostDiff(raw: raw, processed: processed)

        // Evict oldest entry if cache full
        if cache.count >= maxSize {
            cache.removeValue(forKey: cache.keys.first!)
        }

        cache[key] = diff
        return diff
    }

    func clear() {
        cache.removeAll()
    }
}
