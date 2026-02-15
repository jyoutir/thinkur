import SwiftUI

enum Typography {
    static let largeTitle = Font.system(size: 28, weight: .bold)
    static let title = Font.system(size: 22, weight: .bold)
    static let title2 = Font.system(size: 18, weight: .semibold)
    static let title3 = Font.system(size: 16, weight: .semibold)
    static let headline = Font.system(size: 14, weight: .semibold)
    static let body = Font.system(size: 13, weight: .regular)
    static let callout = Font.system(size: 12, weight: .regular)
    static let caption = Font.system(size: 11, weight: .regular)
    static let caption2 = Font.system(size: 10, weight: .regular)

    // Special
    static let statValue = Font.system(size: 36, weight: .bold, design: .rounded)
    static let statUnit = Font.system(size: 14, weight: .medium)
    static let onboardingEmoji = Font.system(size: 64)
    static let onboardingTitle = Font.system(size: 28, weight: .bold)
    static let onboardingBody = Font.system(size: 16, weight: .regular)
    static let keyboardBadge = Font.system(size: 12, weight: .medium, design: .monospaced)
}
