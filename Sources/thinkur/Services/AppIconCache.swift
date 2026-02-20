import AppKit

@MainActor
final class AppIconCache {
    static let shared = AppIconCache()

    private var cache: [String: NSImage?] = [:]
    private var accessOrder: [String] = []
    private let maxSize = 50

    private init() {}

    func icon(for bundleID: String) -> NSImage? {
        // Return cached if available
        if let cached = cache[bundleID] {
            // Move to end (most recently used)
            accessOrder.removeAll { $0 == bundleID }
            accessOrder.append(bundleID)
            return cached
        }

        // Load icon (expensive operation, happens once)
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            cache[bundleID] = nil
            accessOrder.append(bundleID)
            return nil
        }

        // Evict oldest entry if at capacity (LRU eviction)
        if cache.count >= maxSize, let oldest = accessOrder.first {
            cache.removeValue(forKey: oldest)
            accessOrder.removeFirst()
        }

        let icon = NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
        cache[bundleID] = icon
        accessOrder.append(bundleID)
        return icon
    }

    func clearCache() {
        cache.removeAll()
        accessOrder.removeAll()
    }
}
