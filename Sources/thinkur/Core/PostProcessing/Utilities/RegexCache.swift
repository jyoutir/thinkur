import Foundation

final class RegexCache: @unchecked Sendable {
    static let shared = RegexCache()

    private let maxCacheSize = 100
    private var cache: [String: NSRegularExpression] = [:]
    private var accessOrder: [String] = []
    private let lock = NSLock()

    func regex(for pattern: String, options: NSRegularExpression.Options = .caseInsensitive) -> NSRegularExpression? {
        let key = "\(pattern)|\(options.rawValue)"
        lock.lock()
        defer { lock.unlock() }

        if let cached = cache[key] {
            // Move to end (most recently used)
            accessOrder.removeAll { $0 == key }
            accessOrder.append(key)
            return cached
        }

        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return nil
        }

        // Evict oldest entry if at capacity (LRU eviction)
        if cache.count >= maxCacheSize, let oldest = accessOrder.first {
            cache.removeValue(forKey: oldest)
            accessOrder.removeFirst()
        }

        cache[key] = regex
        accessOrder.append(key)
        return regex
    }
}
