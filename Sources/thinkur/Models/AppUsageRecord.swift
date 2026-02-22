import Foundation
import SwiftData

@Model
final class AppUsageRecord {
    @Attribute(.unique) var bundleID: String
    var appName: String
    var totalTranscriptions: Int
    var totalWords: Int
    var totalDuration: Double
    var lastUsed: Date

    init(bundleID: String, appName: String) {
        self.bundleID = bundleID
        self.appName = appName
        self.totalTranscriptions = 0
        self.totalWords = 0
        self.totalDuration = 0
        self.lastUsed = .now
    }
}
