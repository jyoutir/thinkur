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
    case mcp
    case hotkey
    case dictation
    case system
    case hue
    case permissions
    case support

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .shortcuts: return "Shortcuts"
        case .style: return "Style"
        case .insights: return "Insights"
        case .meetings: return "Meetings"
        case .mcp: return "MCP"
        case .hotkey: return "Hotkey"
        case .dictation: return "Dictation"
        case .system: return "System"
        case .hue: return "Hue Bulbs"
        case .permissions: return "Permissions"
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
        case .mcp: return "brain"
        case .hotkey: return "keyboard"
        case .dictation: return "mic"
        case .system: return "gearshape"
        case .hue: return "lightbulb.led.wide"
        case .permissions: return "lock.shield"
        case .support: return "ladybug"
        }
    }

    var section: NavigationSection {
        switch self {
        case .home, .shortcuts, .style, .insights, .meetings, .mcp:
            return .main
        case .hotkey, .dictation, .system, .hue, .permissions, .support:
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
