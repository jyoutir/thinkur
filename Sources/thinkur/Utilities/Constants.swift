import CoreGraphics
import Foundation

enum Constants {
    static let sampleRate: Double = 16_000
    static let tabKeyCode: CGKeyCode = 48
    static let vKeyCode: CGKeyCode = 9
    static let clipboardRestoreDelay: TimeInterval = 0.15
    static let pasteDelay: TimeInterval = 0.05
    static let quickStartModel = "small.en"
    static let whisperModel: String = {
        let ramGB = ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)
        switch ramGB {
        case ..<12:  return "small.en"   // 8GB Macs
        default:     return "medium.en"  // 16GB+
        }
    }()
    // MARK: - TelemetryDeck
    static let telemetryDeckAppID = "1116AAF3-E84E-4353-9024-46C5E05DAB7C"

    // MARK: - LemonSqueezy
    static let lemonSqueezyAPIBase = "https://api.lemonsqueezy.com"
    static let checkoutURLMonthly = "https://thinkur.lemonsqueezy.com/checkout/buy/f178ac35-e7b6-4db2-bb75-e7fd4d4e7981"
    static let checkoutURLLifetime = "https://thinkur.lemonsqueezy.com/checkout/buy/e6442da0-dce6-45cc-a903-a39d9bedb167"
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
