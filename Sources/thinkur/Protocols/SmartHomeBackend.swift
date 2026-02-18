import Foundation

/// A discovered smart light from any backend
struct SmartLight: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let roomName: String?
    var isOn: Bool
    var brightness: Int  // 0-100
    var isReachable: Bool
    let backend: SmartHomeBackendType

    /// Normalized name for matching (lowercase, trimmed)
    var normalizedName: String {
        name.lowercased().trimmingCharacters(in: .whitespaces)
    }

    /// Normalized room name for matching
    var normalizedRoomName: String? {
        roomName?.lowercased().trimmingCharacters(in: .whitespaces)
    }
}

/// Desired state change for a light
struct LightStateChange {
    var on: Bool?
    var brightness: Int?  // 0-100
}

/// Which backend a light comes from
enum SmartHomeBackendType: String, Codable {
    case hue
    case homekit
}

/// Backend-agnostic smart home control
@MainActor
protocol SmartHomeBackend: AnyObject {
    var backendType: SmartHomeBackendType { get }
    var isConnected: Bool { get }
    func connect() async throws
    func disconnect()
    func discoverLights() async throws -> [SmartLight]
    func setLightState(id: String, state: LightStateChange) async throws
}
