import Testing
@testable import thinkur

@Suite("AppStyleMap")
struct AppStyleMapTests {
    @Test func slackIsCasual() {
        #expect(AppStyleMap.style(for: "com.tinyspeck.slackmacgap") == .casual)
    }

    @Test func discordIsCasual() {
        #expect(AppStyleMap.style(for: "com.hnc.Discord") == .casual)
    }

    @Test func mailIsFormal() {
        #expect(AppStyleMap.style(for: "com.apple.mail") == .formal)
    }

    @Test func xcodeIsCode() {
        #expect(AppStyleMap.style(for: "com.apple.dt.Xcode") == .code)
    }

    @Test func vscodeIsCode() {
        #expect(AppStyleMap.style(for: "com.microsoft.VSCode") == .code)
    }

    @Test func unknownBundleIDIsStandard() {
        #expect(AppStyleMap.style(for: "com.unknown.app") == .standard)
    }

    @Test func emptyBundleIDIsStandard() {
        #expect(AppStyleMap.style(for: "") == .standard)
    }
}
