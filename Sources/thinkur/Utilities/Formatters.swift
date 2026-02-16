import Foundation

enum Formatters {
    /// Formats a number with "k" suffix for thousands: 999 → "999", 1000 → "1.0k", 15234 → "15.2k"
    static func compactNumber(_ n: Int) -> String {
        if n >= 1000 {
            return String(format: "%.1fk", Double(n) / 1000.0)
        }
        return "\(n)"
    }

    /// Formats a time interval as human-readable duration: 0-59s → "0m", 1-59m → "Xm", 60m+ → "Xh Ym"
    static func formatTimeSaved(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        if minutes < 1 { return "0m" }
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }
}
