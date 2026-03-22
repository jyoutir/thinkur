import Foundation
import TelemetryDeck
import os

@MainActor
@Observable
final class TelemetryService {
    private let settings: SettingsManager
    private let logger = Logger(subsystem: AppRuntimeConfiguration.loggerSubsystem, category: "TelemetryService")

    // Daily digest state
    private var dailyStats = DailyStats()
    private var lastDigestDate: String?

    init(settings: SettingsManager) {
        self.settings = settings
    }

    func initialize() {
        guard AppRuntimeConfiguration.isTelemetryEnabled else {
            logger.info("Telemetry disabled for dev build")
            return
        }
        let config = TelemetryDeck.Config(appID: Constants.telemetryDeckAppID)
        TelemetryDeck.initialize(config: config)
        lastDigestDate = todayString()
        logger.info("TelemetryDeck initialized")
    }

    // MARK: - Funnel Events

    func trackOnboardingStep(step: Int, stepName: String, durationOnStepSeconds: Int) {
        send("onboarding.stepCompleted", with: [
            "step": "\(step)",
            "stepName": stepName,
            "durationOnStepSeconds": "\(durationOnStepSeconds)",
        ])
    }

    func trackOnboardingCompleted(totalDurationSeconds: Int) {
        send("onboarding.completed", with: [
            "totalDurationSeconds": "\(totalDurationSeconds)",
        ])
    }

    // MARK: - Daily Digest

    func recordTranscription(wordCount: Int, durationSeconds: Double, correctionCount: Int, fillerWordsRemoved: Int, selfCorrectionsUsed: Int) {
        checkAndSendDigestIfNewDay()
        dailyStats.sessionCount += 1
        dailyStats.totalWords += wordCount
        dailyStats.totalDurationSeconds += durationSeconds
        dailyStats.totalCorrections += correctionCount
        dailyStats.fillerWordsRemoved += fillerWordsRemoved
        dailyStats.selfCorrectionsUsed += selfCorrectionsUsed
    }

    func sendPendingDigest() {
        guard dailyStats.sessionCount > 0 else { return }
        sendDailyDigest()
    }

    private func checkAndSendDigestIfNewDay() {
        let today = todayString()
        if let last = lastDigestDate, last != today {
            sendDailyDigest()
            dailyStats = DailyStats()
        }
        lastDigestDate = today
    }

    private func sendDailyDigest() {
        send("daily.digest", with: [
            "sessionCount": "\(dailyStats.sessionCount)",
            "totalWords": "\(dailyStats.totalWords)",
            "totalDurationSeconds": "\(Int(dailyStats.totalDurationSeconds))",
            "totalCorrections": "\(dailyStats.totalCorrections)",
            "fillerWordsRemoved": "\(dailyStats.fillerWordsRemoved)",
            "selfCorrectionsUsed": "\(dailyStats.selfCorrectionsUsed)",
            "holdMode": "\(settings.hotkeyHoldMode)",
            "postProcessingEnabled": "\(settings.postProcessingEnabled)",
            "errorCount": "\(dailyStats.errorCount)",
        ])
        logger.info("Daily digest sent: \(self.dailyStats.sessionCount) sessions, \(self.dailyStats.totalWords) words")
    }

    // MARK: - Error Events

    func trackModelLoadError(modelName: String, errorMessage: String) {
        dailyStats.errorCount += 1
        send("error.modelLoad", with: [
            "modelName": modelName,
            "errorMessage": String(errorMessage.prefix(200)),
        ])
    }

    func trackAudioCaptureError(errorType: String) {
        dailyStats.errorCount += 1
        send("error.audioCapture", with: [
            "errorType": errorType,
        ])
    }

    func trackTranscriptionEmpty(durationSeconds: Double) {
        dailyStats.errorCount += 1
        send("error.transcriptionEmpty", with: [
            "durationSeconds": "\(Int(durationSeconds))",
        ])
    }

    // MARK: - Private

    private func send(_ signalName: String, with parameters: [String: String] = [:]) {
        guard AppRuntimeConfiguration.isTelemetryEnabled else { return }
        guard settings.analyticsEnabled else { return }
        TelemetryDeck.signal(signalName, parameters: parameters)
    }

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }
}

// MARK: - Daily Stats

private struct DailyStats {
    var sessionCount = 0
    var totalWords = 0
    var totalDurationSeconds: Double = 0
    var totalCorrections = 0
    var fillerWordsRemoved = 0
    var selfCorrectionsUsed = 0
    var errorCount = 0
}
