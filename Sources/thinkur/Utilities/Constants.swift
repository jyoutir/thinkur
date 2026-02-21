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
