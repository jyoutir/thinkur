import SwiftUI

enum ThemeMode: String, CaseIterable {
    case light
    case dark

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        }
    }

    var iconName: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var title: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var next: ThemeMode {
        switch self {
        case .light: return .dark
        case .dark: return .light
        }
    }
}
