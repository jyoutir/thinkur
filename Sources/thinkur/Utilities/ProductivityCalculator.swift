import Foundation

enum ProductivityModelDefaults {
    static let typingWPM = 45.0
    static let estimatedWER = 0.05
    static let workdaysPerMonth = 21.0
    static let projectedEffectiveDictationWPM = 110.0
}

struct ProductivitySummary {
    let words: Int
    let durationSeconds: Double
    let rawTimeSavedSeconds: Double
    let displayTimeSavedSeconds: Double
    let moneySaved: Double?
}

enum ProductivityCalculator {
    /// Actual analytics summary from real telemetry (words + duration).
    static func actualSummary(words: Int, durationSeconds: Double, hourlyValue: Double? = nil) -> ProductivitySummary {
        let typedSeconds = (Double(words) / ProductivityModelDefaults.typingWPM) * 60.0
        let editPenaltySeconds = (Double(words) * ProductivityModelDefaults.estimatedWER / ProductivityModelDefaults.typingWPM) * 60.0
        let rawTimeSaved = typedSeconds - durationSeconds - editPenaltySeconds
        let displayTimeSaved = max(0, rawTimeSaved)
        let money = hourlyValue.map { (displayTimeSaved / 3600.0) * $0 }
        return ProductivitySummary(
            words: words,
            durationSeconds: durationSeconds,
            rawTimeSavedSeconds: rawTimeSaved,
            displayTimeSavedSeconds: displayTimeSaved,
            moneySaved: money
        )
    }

    /// Onboarding projection — no telemetry, uses conservative assumptions.
    static func onboardingProjection(typingHoursPerDay: Double, hourlyValue: Double) -> ProductivitySummary {
        let wordsPerDay = Int(typingHoursPerDay * 60.0 * ProductivityModelDefaults.typingWPM)
        let typedSecondsPerDay = typingHoursPerDay * 3600.0
        let projectedDictationSecondsPerDay = (Double(wordsPerDay) / ProductivityModelDefaults.projectedEffectiveDictationWPM) * 60.0
        let dailyTimeSaved = max(0, typedSecondsPerDay - projectedDictationSecondsPerDay)
        let monthlyTimeSaved = dailyTimeSaved * ProductivityModelDefaults.workdaysPerMonth
        let monthlyMoney = (monthlyTimeSaved / 3600.0) * hourlyValue
        return ProductivitySummary(
            words: wordsPerDay,
            durationSeconds: projectedDictationSecondsPerDay,
            rawTimeSavedSeconds: monthlyTimeSaved,
            displayTimeSavedSeconds: monthlyTimeSaved,
            moneySaved: monthlyMoney
        )
    }
}
