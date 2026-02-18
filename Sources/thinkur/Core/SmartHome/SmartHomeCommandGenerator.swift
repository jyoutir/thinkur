import Foundation

/// Auto-generates voice commands from discovered lights and rooms
struct SmartHomeCommandGenerator {

    /// Generate all commands for a set of discovered lights
    static func generateCommands(from lights: [SmartLight]) -> [SmartHomeCommand] {
        var commands: [SmartHomeCommand] = []

        // Per-light commands
        for light in lights {
            commands.append(contentsOf: generateLightCommands(for: light))
        }

        // Per-room commands (group lights by room)
        let roomGroups = Dictionary(grouping: lights.filter { $0.roomName != nil }, by: { $0.roomName! })
        for (roomName, roomLights) in roomGroups {
            // Use the first light's ID as representative for room-level control
            // SmartHomeService will handle expanding to all lights in the room
            guard let representative = roomLights.first else { continue }
            commands.append(contentsOf: generateRoomCommands(roomName: roomName, representativeLightId: representative.id))
        }

        return commands
    }

    /// Generate commands for a single light
    static func generateLightCommands(for light: SmartLight) -> [SmartHomeCommand] {
        let name = light.normalizedName
        return [
            SmartHomeCommand(
                triggerPhrases: ["turn on \(name)", "\(name) on"],
                action: .turnOn,
                targetLightId: light.id,
                targetName: light.name
            ),
            SmartHomeCommand(
                triggerPhrases: ["turn off \(name)", "\(name) off"],
                action: .turnOff,
                targetLightId: light.id,
                targetName: light.name
            ),
            SmartHomeCommand(
                triggerPhrases: ["dim \(name)", "dim the \(name)"],
                action: .dim,
                targetLightId: light.id,
                targetName: light.name
            ),
            SmartHomeCommand(
                triggerPhrases: ["brighten \(name)", "brighten the \(name)"],
                action: .brighten,
                targetLightId: light.id,
                targetName: light.name
            ),
            SmartHomeCommand(
                triggerPhrases: ["\(name) full brightness", "\(name) max"],
                action: .fullBrightness,
                targetLightId: light.id,
                targetName: light.name
            ),
        ]
    }

    /// Generate room-level commands
    static func generateRoomCommands(roomName: String, representativeLightId: String) -> [SmartHomeCommand] {
        let name = roomName.lowercased().trimmingCharacters(in: .whitespaces)
        return [
            SmartHomeCommand(
                triggerPhrases: ["turn on \(name) lights", "turn on the \(name) lights", "\(name) lights on"],
                action: .turnOn,
                targetLightId: representativeLightId,
                targetName: "\(roomName) lights",
                isRoomLevel: true
            ),
            SmartHomeCommand(
                triggerPhrases: ["turn off \(name) lights", "turn off the \(name) lights", "\(name) lights off"],
                action: .turnOff,
                targetLightId: representativeLightId,
                targetName: "\(roomName) lights",
                isRoomLevel: true
            ),
            SmartHomeCommand(
                triggerPhrases: ["dim \(name) lights", "dim the \(name) lights"],
                action: .dim,
                targetLightId: representativeLightId,
                targetName: "\(roomName) lights",
                isRoomLevel: true
            ),
            SmartHomeCommand(
                triggerPhrases: ["brighten \(name) lights", "brighten the \(name) lights"],
                action: .brighten,
                targetLightId: representativeLightId,
                targetName: "\(roomName) lights",
                isRoomLevel: true
            ),
        ]
    }
}
