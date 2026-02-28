import SwiftUI

enum MeetingSpeakerColor: Int, CaseIterable {
    case teal = 0
    case coral
    case violet
    case amber
    case indigo
    case mint
    case rose
    case sky

    var color: Color {
        switch self {
        case .teal: return Color(red: 0.0, green: 0.78, blue: 0.75)
        case .coral: return Color(red: 1.0, green: 0.45, blue: 0.38)
        case .violet: return Color(red: 0.55, green: 0.35, blue: 0.95)
        case .amber: return Color(red: 1.0, green: 0.72, blue: 0.0)
        case .indigo: return Color(red: 0.35, green: 0.35, blue: 0.85)
        case .mint: return Color(red: 0.0, green: 0.82, blue: 0.58)
        case .rose: return Color(red: 0.95, green: 0.35, blue: 0.55)
        case .sky: return Color(red: 0.3, green: 0.65, blue: 1.0)
        }
    }

    /// "local" always gets teal (index 0). Remote speakers hash to the remaining colors.
    static func color(for speakerId: String) -> Color {
        if speakerId == "local" {
            return allCases[0].color
        }
        // Use remaining colors (skip teal at index 0) for remote speakers
        let remoteColors = Array(allCases.dropFirst())
        let index = abs(speakerId.hashValue) % remoteColors.count
        return remoteColors[index].color
    }
}
