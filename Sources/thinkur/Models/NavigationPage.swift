import Foundation

enum NavigationSection: String, CaseIterable {
    case main = "Main"
    case settings = "Settings"
}

enum NavigationPage: String, CaseIterable, Identifiable, Hashable {
    case home
    case shortcuts
    case style
    case insights
    case meetings
    case integrations
    case hotkey
    case dictation
    case system
    case permissions
    case billing
    case support

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .shortcuts: return "Shortcuts"
        case .style: return "Style"
        case .insights: return "Insights"
        case .meetings: return "Meetings"
        case .integrations: return "Integrations"
        case .hotkey: return "Hotkey"
        case .dictation: return "Dictation"
        case .system: return "System"
        case .permissions: return "Permissions"
        case .billing: return "Billing"
        case .support: return "Support"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .shortcuts: return "text.badge.plus"
        case .style: return "paintbrush"
        case .insights: return "chart.bar"
        case .meetings: return "person.2.wave.2"
        case .integrations: return "lightbulb.led.wide"
        case .hotkey: return "keyboard"
        case .dictation: return "mic"
        case .system: return "gearshape"
        case .permissions: return "lock.shield"
        case .billing: return "creditcard"
        case .support: return "ladybug"
        }
    }

    var section: NavigationSection {
        switch self {
        case .home, .shortcuts, .style, .insights, .meetings, .integrations:
            return .main
        case .hotkey, .dictation, .system, .permissions, .billing, .support:
            return .settings
        }
    }

    static var mainPages: [NavigationPage] {
        allCases.filter { $0.section == .main }
    }

    static var settingsPages: [NavigationPage] {
        allCases.filter { $0.section == .settings }
    }
}
