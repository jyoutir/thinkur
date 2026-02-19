import Foundation

/// A discovered smart light from any backend
struct SmartLight: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    let originalName: String
    let roomName: String?
    var isOn: Bool
    var brightness: Int  // 0-100
    var colorTemperature: Int?  // mirek (153=cool ~6500K, 500=warm ~2000K), nil if not supported
    var isReachable: Bool
    let backend: SmartHomeBackendType

    init(
        id: String,
        name: String,
        originalName: String? = nil,
        roomName: String?,
        isOn: Bool,
        brightness: Int,
        colorTemperature: Int? = nil,
        isReachable: Bool,
        backend: SmartHomeBackendType
    ) {
        self.id = id
        self.name = name
        self.originalName = originalName ?? name
        self.roomName = roomName
        self.isOn = isOn
        self.brightness = brightness
        self.colorTemperature = colorTemperature
        self.isReachable = isReachable
        self.backend = backend
    }

    /// Normalized name for matching (lowercase, trimmed)
    var normalizedName: String {
        name.lowercased().trimmingCharacters(in: .whitespaces)
    }

    /// Normalized original name for matching
    var normalizedOriginalName: String {
        originalName.lowercased().trimmingCharacters(in: .whitespaces)
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
    var colorTemperature: Int?  // mirek (153-500)
}

/// Which backend a light comes from
enum SmartHomeBackendType: String, Codable {
    case hue
    case homekit
    case hueBluetooth
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
