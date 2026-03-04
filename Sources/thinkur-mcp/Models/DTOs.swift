import Foundation

// MARK: - Core Data epoch offset (2001-01-01 → Unix epoch)
let coreDataEpochOffset: Double = 978_307_200

func coreDataDateToISO8601(_ timestamp: Double) -> String {
    let date = Date(timeIntervalSince1970: timestamp + coreDataEpochOffset)
    return ISO8601DateFormatter().string(from: date)
}

// MARK: - Transcription

struct MCPTranscription: Codable {
    let rawText: String
    let processedText: String
    let duration: Double
    let timestamp: String
    let appBundleID: String
    let appName: String
    let wordCount: Int
    let correctionCount: Int
}

// MARK: - Daily Analytics

struct MCPDailyAnalytics: Codable {
    let date: String
    let transcriptionCount: Int
    let totalWords: Int
    let totalDuration: Double
}

// MARK: - App Usage

struct MCPAppUsage: Codable {
    let bundleID: String
    let appName: String
    let totalTranscriptions: Int
    let totalWords: Int
    let totalDuration: Double
    let lastUsed: String
}

// MARK: - Shortcut

struct MCPShortcut: Codable {
    let trigger: String
    let expansion: String
}

// MARK: - Session (grouped transcriptions)

struct MCPSession: Codable {
    let appName: String
    let appBundleID: String
    let startTime: String
    let endTime: String
    let totalDuration: Double
    let totalWords: Int
    let transcriptionCount: Int
    let combinedText: String
}

// MARK: - Meeting

struct MCPMeeting: Codable {
    let title: String
    let date: String
    let duration: Double
    let speakerCount: Int
    let segments: [MCPMeetingSegment]
}

struct MCPMeetingSegment: Codable {
    let speakerId: String
    let text: String
    let startTime: Double
    let endTime: Double
}

// MARK: - Analytics Summary

struct MCPAnalyticsSummary: Codable {
    let totalWords: Int
    let totalSessions: Int
    let totalDuration: Double
    let estimatedTimeSaved: Double
}
