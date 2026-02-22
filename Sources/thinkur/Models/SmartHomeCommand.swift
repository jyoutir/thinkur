import Foundation

/// An action that can be performed on a smart light
enum SmartHomeAction: String, Codable {
    case turnOn
    case turnOff
    case setBrightness  // brightness value parsed from phrase
    case dim            // -25%
    case brighten       // +25%
    case fullBrightness // 100%
}

/// A voice command that maps trigger phrases to a light action
struct SmartHomeCommand: Identifiable, Codable, Equatable {
    let id: UUID
    let triggerPhrases: [String]
    let action: SmartHomeAction
    let targetLightId: String
    let targetName: String         // for display
    let isRoomLevel: Bool

    init(
        triggerPhrases: [String],
        action: SmartHomeAction,
        targetLightId: String,
        targetName: String,
        isRoomLevel: Bool = false
    ) {
        self.id = UUID()
        self.triggerPhrases = triggerPhrases
        self.action = action
        self.targetLightId = targetLightId
        self.targetName = targetName
        self.isRoomLevel = isRoomLevel
    }
}

/// Result of matching transcribed text against smart home commands
struct SmartHomeMatchResult {
    let command: SmartHomeCommand
    let parsedBrightness: Int?  // Only set for .setBrightness
}
