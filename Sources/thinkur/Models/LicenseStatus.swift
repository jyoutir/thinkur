import Foundation

enum LicenseStatus: String, Codable {
    case unlicensed
    case validating
    case active
    case expired
    case invalid
}
