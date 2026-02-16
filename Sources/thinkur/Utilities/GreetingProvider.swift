import Foundation

enum GreetingProvider {
    /// The user's first name extracted from macOS account.
    static var firstName: String {
        let fullName = NSFullUserName()
        let first = fullName.split(separator: " ").first.map(String.init) ?? fullName
        return first.isEmpty ? "there" : first
    }

    /// Rotating phrases (without the name — name goes on its own line).
    static func phrases() -> [String] {
        let hour = Calendar.current.component(.hour, from: Date())
        var pool: [String]
        switch hour {
        case 0..<12:
            pool = ["Good morning...", "Rise and shine..."]
        case 12..<17:
            pool = ["Good afternoon...", "Welcome back..."]
        default:
            pool = ["Good evening...", "Winding down..."]
        }
        pool += [
            "Let's get thinking...",
            "Don't type, just speak...",
            "Ready when you are...",
            "What's on your mind...",
        ]
        return pool.shuffled()
    }

    /// Formatted current date string (e.g. "Sunday, February 16")
    static var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    /// Legacy single greeting (used by pages that don't animate).
    static func greeting() -> String {
        let name = firstName
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning, \(name)"
        case 12..<17: return "Good afternoon, \(name)"
        default: return "Good evening, \(name)"
        }
    }
}
