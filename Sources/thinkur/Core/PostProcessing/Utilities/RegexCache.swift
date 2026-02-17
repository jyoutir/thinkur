import Foundation

final class RegexCache: @unchecked Sendable {
    static let shared = RegexCache()

    private var cache: [String: NSRegularExpression] = [:]
    private let lock = NSLock()

    func regex(for pattern: String, options: NSRegularExpression.Options = .caseInsensitive) -> NSRegularExpression? {
        let key = "\(pattern)|\(options.rawValue)"
        lock.lock()
        defer { lock.unlock() }

        if let cached = cache[key] {
            return cached
        }

        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return nil
        }
        cache[key] = regex
        return regex
    }
}
