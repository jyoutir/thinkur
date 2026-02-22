import Foundation
import SwiftData

@Model
final class TranscriptionRecord {
    var rawText: String
    var processedText: String
    var duration: Double
    var timestamp: Date
    var appBundleID: String
    var appName: String
    var wordCount: Int
    var correctionCount: Int = 0

    init(rawText: String, processedText: String, duration: Double, timestamp: Date = .now, appBundleID: String, appName: String, correctionCount: Int = 0) {
        self.rawText = rawText
        self.processedText = processedText
        self.duration = duration
        self.timestamp = timestamp
        self.appBundleID = appBundleID
        self.appName = appName
        self.wordCount = processedText.split(separator: " ").count
        self.correctionCount = correctionCount
    }
}
