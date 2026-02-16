import Foundation

enum GreetingProvider {
    /// Returns a time-aware, personalized greeting for the current user.
    /// Picks one randomly per call — caller should cache per app launch.
    static func greeting() -> String {
        let firstName = extractFirstName()
        let hour = Calendar.current.component(.hour, from: Date())
        let pool = greetingPool(for: hour, name: firstName)
        return pool.randomElement() ?? "Hello, \(firstName)"
    }

    /// Formatted current date string (e.g. "Sunday, February 16")
    static var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    private static func extractFirstName() -> String {
        let fullName = NSFullUserName()
        let first = fullName.split(separator: " ").first.map(String.init) ?? fullName
        return first.isEmpty ? "there" : first
    }

    private static func greetingPool(for hour: Int, name: String) -> [String] {
        var pool: [String]
        switch hour {
        case 0..<12:
            pool = [
                "Good morning, \(name)",
                "Rise and shine, \(name)",
            ]
        case 12..<17:
            pool = [
                "Good afternoon, \(name)",
                "Welcome back, \(name)",
            ]
        default:
            pool = [
                "Good evening, \(name)",
                "Winding down, \(name)?",
            ]
        }
        // Anytime greetings mixed in
        pool += [
            "Ready to dictate, \(name)?",
            "Let's get typing, \(name)",
        ]
        return pool
    }
}
