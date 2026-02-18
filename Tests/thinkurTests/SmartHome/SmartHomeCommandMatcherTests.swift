import Testing
@testable import thinkur

@Suite("SmartHomeCommandMatcher")
struct SmartHomeCommandMatcherTests {

    private func makeCommands() -> [SmartHomeCommand] {
        let lights = [
            SmartLight(id: "1", name: "Desk Lamp", roomName: "Office", isOn: false, brightness: 0, isReachable: true, backend: .hue),
            SmartLight(id: "2", name: "Floor Lamp", roomName: "Living Room", isOn: true, brightness: 50, isReachable: true, backend: .hue),
        ]
        return SmartHomeCommandGenerator.generateCommands(from: lights)
    }

    // MARK: - Exact Phrase Matching

    @Test("Matches exact turn on phrase")
    func matchesTurnOn() {
        let commands = makeCommands()
        let result = SmartHomeCommandMatcher.match(text: "turn on desk lamp", commands: commands)
        #expect(result != nil)
        #expect(result!.command.action == .turnOn)
        #expect(result!.command.targetLightId == "1")
    }

    @Test("Matches exact turn off phrase")
    func matchesTurnOff() {
        let commands = makeCommands()
        let result = SmartHomeCommandMatcher.match(text: "turn off floor lamp", commands: commands)
        #expect(result != nil)
        #expect(result!.command.action == .turnOff)
        #expect(result!.command.targetLightId == "2")
    }

    @Test("Matches alternate phrase order")
    func matchesAlternateOrder() {
        let commands = makeCommands()
        let result = SmartHomeCommandMatcher.match(text: "desk lamp on", commands: commands)
        #expect(result != nil)
        #expect(result!.command.action == .turnOn)
    }

    @Test("Matches dim command")
    func matchesDim() {
        let commands = makeCommands()
        let result = SmartHomeCommandMatcher.match(text: "dim desk lamp", commands: commands)
        #expect(result != nil)
        #expect(result!.command.action == .dim)
    }

    @Test("Matches room-level command")
    func matchesRoom() {
        let commands = makeCommands()
        let result = SmartHomeCommandMatcher.match(text: "turn on office lights", commands: commands)
        #expect(result != nil)
        #expect(result!.command.action == .turnOn)
        #expect(result!.command.isRoomLevel == true)
    }

    // MARK: - Filler Stripping

    @Test("Strips filler words before matching")
    func stripsFillers() {
        let commands = makeCommands()
        let result = SmartHomeCommandMatcher.match(text: "um please turn on the desk lamp", commands: commands)
        #expect(result != nil)
        #expect(result!.command.action == .turnOn)
        #expect(result!.command.targetLightId == "1")
    }

    @Test("Strips 'the' for dim command")
    func stripsTheForDim() {
        let commands = makeCommands()
        let result = SmartHomeCommandMatcher.match(text: "dim the desk lamp", commands: commands)
        #expect(result != nil)
        #expect(result!.command.action == .dim)
    }

    @Test("Case insensitive matching")
    func caseInsensitive() {
        let commands = makeCommands()
        let result = SmartHomeCommandMatcher.match(text: "Turn On Desk Lamp", commands: commands)
        #expect(result != nil)
        #expect(result!.command.action == .turnOn)
    }

    // MARK: - Brightness Parsing

    @Test("Parses brightness percentage")
    func parsesBrightness() {
        let commands = makeCommands()
        let result = SmartHomeCommandMatcher.match(text: "set desk lamp to 50 percent", commands: commands)
        #expect(result != nil)
        #expect(result!.command.action == .setBrightness)
        #expect(result!.parsedBrightness == 50)
        #expect(result!.command.targetLightId == "1")
    }

    @Test("Parses brightness with % symbol")
    func parsesBrightnessPercent() {
        let commands = makeCommands()
        let result = SmartHomeCommandMatcher.match(text: "set desk lamp to 75%", commands: commands)
        #expect(result != nil)
        #expect(result!.parsedBrightness == 75)
    }

    @Test("Rejects out-of-range brightness")
    func rejectsOutOfRange() {
        let commands = makeCommands()
        let result = SmartHomeCommandMatcher.match(text: "set desk lamp to 150 percent", commands: commands)
        #expect(result == nil)
    }

    // MARK: - No Match

    @Test("Returns nil for unrelated text")
    func noMatchForNormalText() {
        let commands = makeCommands()
        let result = SmartHomeCommandMatcher.match(text: "hello world this is a test", commands: commands)
        #expect(result == nil)
    }

    @Test("Returns nil for empty text")
    func noMatchForEmpty() {
        let commands = makeCommands()
        let result = SmartHomeCommandMatcher.match(text: "", commands: commands)
        #expect(result == nil)
    }

    @Test("Returns nil for empty commands list")
    func noMatchEmptyCommands() {
        let result = SmartHomeCommandMatcher.match(text: "turn on desk lamp", commands: [])
        #expect(result == nil)
    }

    // MARK: - Filler Stripping Unit

    @Test("stripFillers removes common fillers")
    func stripFillersUnit() {
        #expect(SmartHomeCommandMatcher.stripFillers("um turn on the lights please") == "turn on lights")
        #expect(SmartHomeCommandMatcher.stripFillers("hey can you just dim my lamp") == "dim lamp")
    }

    @Test("stripFillers preserves meaningful words")
    func stripFillersPreserves() {
        #expect(SmartHomeCommandMatcher.stripFillers("turn on desk lamp") == "turn on desk lamp")
    }
}
