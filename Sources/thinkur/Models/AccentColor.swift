import SwiftUI

enum AccentColor: String, CaseIterable, Identifiable {
    case lavender
    case blue
    case cyan
    case teal
    case defaultGreen
    case lime
    case yellow
    case orange
    case coral
    case pink
    case white

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .lavender:      return Color(hex: "BFA0F8")
        case .blue:          return Color(hex: "7EA3F5")
        case .cyan:          return Color(hex: "4DBCE8")
        case .teal:          return Color(hex: "34D4A8")
        case .defaultGreen:  return Color(hex: "5CD47E")
        case .lime:          return Color(hex: "A0CC4A")
        case .yellow:        return Color(hex: "D4BC38")
        case .orange:        return Color(hex: "F09C48")
        case .coral:         return Color(hex: "F47C68")
        case .pink:          return Color(hex: "F474AC")
        case .white:         return .white
        }
    }

    /// For UI tint usage: white is invisible on light backgrounds, so fall back to `.primary`.
    var uiTintColor: Color {
        self == .white ? .primary : color
    }

    var displayName: String {
        switch self {
        case .lavender:      return "Lavender"
        case .blue:          return "Blue"
        case .cyan:          return "Cyan"
        case .teal:          return "Teal"
        case .defaultGreen:  return "Green"
        case .lime:          return "Lime"
        case .yellow:        return "Yellow"
        case .orange:        return "Orange"
        case .coral:         return "Coral"
        case .pink:          return "Pink"
        case .white:         return "White"
        }
    }
}
