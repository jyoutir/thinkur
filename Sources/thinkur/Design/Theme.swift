import SwiftUI
import AppKit

enum ColorTokens {
    // Backgrounds
    static let windowBackground = Color(nsColor: .windowBackgroundColor)
    static let cardBackground = Color(light: Color(hex: "FFFFFF", opacity: 0.6), dark: Color(hex: "1C1C1E", opacity: 0.6))
    static let sidebarBackground = Color(nsColor: .controlBackgroundColor)

    // Text
    static let textPrimary = Color(nsColor: .labelColor)
    static let textSecondary = Color(nsColor: .secondaryLabelColor)
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)

    // Semantic
    static let success = Color(nsColor: .labelColor)
    static let warning = Color(nsColor: .labelColor)
    static let danger = Color(nsColor: .labelColor)

    // Borders
    static let separator = Color(nsColor: .separatorColor)
    static let border = Color(light: Color(hex: "E5E5EA"), dark: Color(hex: "38383A"))
}

extension Color {
    init(hex: String, opacity: Double = 1.0) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            switch appearance.bestMatch(from: [.aqua, .darkAqua]) {
            case .darkAqua:
                return NSColor(dark)
            default:
                return NSColor(light)
            }
        }))
    }
}
