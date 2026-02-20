import SwiftUI

@MainActor
final class DiffCache {
    static let shared = DiffCache()

    private var cache: [String: AttributedString] = [:]
    private var accessOrder: [String] = []
    private let maxSize = 500

    private init() {}

    func getDiff(raw: String, processed: String) -> AttributedString {
        let key = "\(raw.hashValue):\(processed.hashValue)"

        if let cached = cache[key] {
            // Move to end (most recently used)
            accessOrder.removeAll { $0 == key }
            accessOrder.append(key)
            return cached
        }

        let diff = TextDiffBuilder.buildGhostDiff(raw: raw, processed: processed)

        // Evict oldest entry if at capacity (LRU eviction)
        if cache.count >= maxSize, let oldest = accessOrder.first {
            cache.removeValue(forKey: oldest)
            accessOrder.removeFirst()
        }

        cache[key] = diff
        accessOrder.append(key)
        return diff
    }

    func clear() {
        cache.removeAll()
        accessOrder.removeAll()
    }
}
