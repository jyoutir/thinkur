import Foundation

enum InsightsPeriod: String, CaseIterable, Identifiable {
    case sevenDays = "7D"
    case fourteenDays = "14D"
    case thirtyDays = "30D"

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .sevenDays: return 7
        case .fourteenDays: return 14
        case .thirtyDays: return 30
        }
    }

    var label: String {
        switch self {
        case .sevenDays: return "7 Days"
        case .fourteenDays: return "14 Days"
        case .thirtyDays: return "30 Days"
        }
    }
}
