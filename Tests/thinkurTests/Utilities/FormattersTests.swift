import Testing
@testable import thinkur

@Suite("Formatters")
struct FormattersTests {
    // MARK: - compactNumber

    @Test func compactNumberUnderThousand() {
        #expect(Formatters.compactNumber(0) == "0")
        #expect(Formatters.compactNumber(999) == "999")
        #expect(Formatters.compactNumber(42) == "42")
    }

    @Test func compactNumberThousands() {
        #expect(Formatters.compactNumber(1000) == "1.0k")
        #expect(Formatters.compactNumber(1500) == "1.5k")
        #expect(Formatters.compactNumber(15234) == "15.2k")
    }

    @Test func compactNumberLargeNumbers() {
        #expect(Formatters.compactNumber(100000) == "100.0k")
        #expect(Formatters.compactNumber(999999) == "1000.0k")
    }

    // MARK: - formatTimeSaved

    @Test func formatTimeSavedZero() {
        #expect(Formatters.formatTimeSaved(0) == "0m")
    }

    @Test func formatTimeSavedUnderMinute() {
        #expect(Formatters.formatTimeSaved(30) == "0m")
        #expect(Formatters.formatTimeSaved(59) == "0m")
    }

    @Test func formatTimeSavedMinutes() {
        #expect(Formatters.formatTimeSaved(60) == "1m")
        #expect(Formatters.formatTimeSaved(300) == "5m")
        #expect(Formatters.formatTimeSaved(3540) == "59m")
    }

    @Test func formatTimeSavedHours() {
        #expect(Formatters.formatTimeSaved(3600) == "1h 0m")
        #expect(Formatters.formatTimeSaved(5400) == "1h 30m")
        #expect(Formatters.formatTimeSaved(7200) == "2h 0m")
    }
}
