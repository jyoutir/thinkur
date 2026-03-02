import Testing
@testable import thinkur

@Suite("ProductivityCalculator")
struct ProductivityCalculatorTests {

    // MARK: - Actual Summary

    @Test func standardPositiveSavings() {
        // 450 words at 45 WPM = 600s to type. Edit penalty = 450*0.05/45*60 = 30s.
        // Net = 600 - 300 - 30 = 270s saved.
        let summary = ProductivityCalculator.actualSummary(words: 450, durationSeconds: 300)
        #expect(summary.rawTimeSavedSeconds == 270.0)
        #expect(summary.displayTimeSavedSeconds == 270.0)
        #expect(summary.moneySaved == nil)
    }

    @Test func silenceHeavySessionClampedToZero() {
        // 100 words at 45 WPM = 133.3s to type. Edit penalty ≈ 6.67s.
        // Net = 133.3 - 600 - 6.67 ≈ -473.3 (negative).
        let summary = ProductivityCalculator.actualSummary(words: 100, durationSeconds: 600)
        #expect(summary.rawTimeSavedSeconds < 0)
        #expect(summary.displayTimeSavedSeconds == 0)
    }

    @Test func werPenaltyReducesSavings() {
        let withPenalty = ProductivityCalculator.actualSummary(words: 450, durationSeconds: 300)
        // Without WER penalty: (450/45)*60 - 300 = 300s
        // With 5% WER penalty: 300 - 30 = 270s
        #expect(withPenalty.rawTimeSavedSeconds < 300.0)
    }

    @Test func moneyConversion() {
        let summary = ProductivityCalculator.actualSummary(words: 450, durationSeconds: 300, hourlyValue: 50.0)
        // 270s saved at $50/hr = 270/3600 * 50 = $3.75
        #expect(summary.moneySaved! == 3.75)
    }

    @Test func zeroWordsProducesZeroSavings() {
        let summary = ProductivityCalculator.actualSummary(words: 0, durationSeconds: 5.0)
        #expect(summary.rawTimeSavedSeconds < 0)
        #expect(summary.displayTimeSavedSeconds == 0)
    }

    // MARK: - Onboarding Projection

    @Test func onboardingProjection() {
        let summary = ProductivityCalculator.onboardingProjection(typingHoursPerDay: 2.0, hourlyValue: 25.0)
        // wordsPerDay = 2.0 * 60 * 45 = 5400
        #expect(summary.words == 5400)
        // typedSecondsPerDay = 2.0 * 3600 = 7200
        // dictationSecondsPerDay = (5400/110)*60 ≈ 2945.45
        // dailyTimeSaved = 7200 - 2945.45 ≈ 4254.55
        // monthlyTimeSaved = 4254.55 * 21 ≈ 89345.45
        #expect(summary.displayTimeSavedSeconds > 0)
        // monthlyMoney = (89345.45/3600) * 25 ≈ 620.45
        #expect(summary.moneySaved! > 600)
        #expect(summary.moneySaved! < 650)
    }

    @Test func onboardingProjectionNeverNegative() {
        // Even with minimal typing, projection should be non-negative
        let summary = ProductivityCalculator.onboardingProjection(typingHoursPerDay: 0.5, hourlyValue: 10.0)
        #expect(summary.displayTimeSavedSeconds >= 0)
    }

    // MARK: - Defaults

    @Test func defaultsAreCanonical() {
        #expect(ProductivityModelDefaults.typingWPM == 45.0)
        #expect(ProductivityModelDefaults.estimatedWER == 0.05)
        #expect(ProductivityModelDefaults.workdaysPerMonth == 21.0)
        #expect(ProductivityModelDefaults.projectedEffectiveDictationWPM == 110.0)
    }
}
