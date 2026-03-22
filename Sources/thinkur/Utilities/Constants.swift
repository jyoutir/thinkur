import CoreGraphics
import Foundation

enum Constants {
    static let sampleRate: Double = 16_000
    static let tabKeyCode: CGKeyCode = 48
    static let vKeyCode: CGKeyCode = 9
    static let clipboardRestoreDelay: TimeInterval = 0.15
    static let pasteDelay: TimeInterval = 0.05

    // MARK: - TelemetryDeck
    static let telemetryDeckAppID = "1116AAF3-E84E-4353-9024-46C5E05DAB7C"

    static let appSupportDirectory: URL = {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent(AppRuntimeConfiguration.supportDirectoryName, isDirectory: true)
        try? fm.createDirectory(
            at: dir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        return dir
    }()
}
