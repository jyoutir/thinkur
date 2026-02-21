import CoreGraphics
import Foundation

enum Constants {
    static let sampleRate: Double = 16_000
    static let tabKeyCode: CGKeyCode = 48
    static let vKeyCode: CGKeyCode = 9
    static let clipboardRestoreDelay: TimeInterval = 0.15
    static let pasteDelay: TimeInterval = 0.05
    static let whisperModel: String = {
        let ramGB = ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)
        switch ramGB {
        case ..<12:  return "small.en"   // 8GB Macs
        default:     return "medium.en"  // 16GB+
        }
    }()
    // MARK: - LemonSqueezy
    static let lemonSqueezyAPIBase = "https://api.lemonsqueezy.com"
    static let checkoutURLMonthly = "https://thinkur.lemonsqueezy.com/checkout/buy/eb346813-5cda-438c-b748-0a6d506e0969"
    static let checkoutURLLifetime = "https://thinkur.lemonsqueezy.com/checkout/buy/4c77431c-ca9c-4883-a857-3e24e83f0a9d"
    static let customerPortalURL = "https://thinkur.lemonsqueezy.com/billing"

    static let appSupportDirectory: URL = {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("thinkur", isDirectory: true)
        try? fm.createDirectory(
            at: dir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        return dir
    }()
}
