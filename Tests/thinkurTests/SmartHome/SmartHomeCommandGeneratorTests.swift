import Testing
@testable import thinkur

@Suite("SmartHomeCommandGenerator")
struct SmartHomeCommandGeneratorTests {

    private func makeLights() -> [SmartLight] {
        [
            SmartLight(id: "1", name: "Desk Lamp", roomName: "Office", isOn: true, brightness: 80, isReachable: true, backend: .hue),
            SmartLight(id: "2", name: "Ceiling Light", roomName: "Office", isOn: false, brightness: 0, isReachable: true, backend: .hue),
            SmartLight(id: "3", name: "Floor Lamp", roomName: "Living Room", isOn: true, brightness: 50, isReachable: true, backend: .hue),
        ]
    }

    @Test("Generates per-light commands for each light")
    func generatesPerLightCommands() {
        let lights = makeLights()
        let commands = SmartHomeCommandGenerator.generateCommands(from: lights)

        // Each light gets 5 commands (on, off, dim, brighten, full)
        let deskLampCommands = commands.filter { $0.targetLightId == "1" && !$0.isRoomLevel }
        #expect(deskLampCommands.count == 5)

        // Check turn on phrases
        let turnOn = deskLampCommands.first { $0.action == .turnOn }
        #expect(turnOn != nil)
        #expect(turnOn!.triggerPhrases.contains("turn on desk lamp"))
        #expect(turnOn!.triggerPhrases.contains("desk lamp on"))
    }

    @Test("Generates room-level commands for rooms with lights")
    func generatesRoomCommands() {
        let lights = makeLights()
        let commands = SmartHomeCommandGenerator.generateCommands(from: lights)

        let officeRoomCommands = commands.filter { $0.isRoomLevel && $0.targetName.contains("Office") }
        #expect(officeRoomCommands.count == 4)  // on, off, dim, brighten

        let turnOnRoom = officeRoomCommands.first { $0.action == .turnOn }
        #expect(turnOnRoom != nil)
        #expect(turnOnRoom!.triggerPhrases.contains("turn on office lights"))
        #expect(turnOnRoom!.triggerPhrases.contains("turn on the office lights"))
    }

    @Test("No room commands for lights without room names")
    func noRoomForOrphans() {
        let lights = [
            SmartLight(id: "1", name: "Solo Lamp", roomName: nil, isOn: true, brightness: 80, isReachable: true, backend: .hue),
        ]
        let commands = SmartHomeCommandGenerator.generateCommands(from: lights)

        let roomCommands = commands.filter { $0.isRoomLevel }
        #expect(roomCommands.isEmpty)
    }

    @Test("Command names are lowercased")
    func phrasesAreLowercased() {
        let lights = [
            SmartLight(id: "1", name: "Desk Lamp", roomName: nil, isOn: true, brightness: 80, isReachable: true, backend: .hue),
        ]
        let commands = SmartHomeCommandGenerator.generateCommands(from: lights)

        for command in commands {
            for phrase in command.triggerPhrases {
                #expect(phrase == phrase.lowercased(), "Phrase '\(phrase)' should be lowercase")
            }
        }
    }

    @Test("Commands use custom name when originalName differs")
    func commandsUseCustomName() {
        let lights = [
            SmartLight(id: "1", name: "My Desk Light", originalName: "Lamp", roomName: nil, isOn: true, brightness: 80, isReachable: true, backend: .hue),
        ]
        let commands = SmartHomeCommandGenerator.generateCommands(from: lights)

        let turnOn = commands.first { $0.action == .turnOn }
        #expect(turnOn != nil)
        #expect(turnOn!.triggerPhrases.contains("turn on my desk light"))
        #expect(turnOn!.targetName == "My Desk Light")
    }
}
