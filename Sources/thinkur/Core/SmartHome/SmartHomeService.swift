import Foundation
import os

/// Orchestrates smart home backends, manages commands, and handles voice-to-action matching
@MainActor
@Observable
final class SmartHomeService {
    private(set) var backends: [any SmartHomeBackend] = []
    private(set) var lights: [SmartLight] = []
    private(set) var commands: [SmartHomeCommand] = []
    private(set) var isRefreshing = false
    var lastActionMessage: String?

    let hueBackend = HueBridgeBackend()
    var homeKitBackend: HomeKitBackend?
    var hueBluetoothBackend: HueBluetoothBackend?

    var hasAnyConnection: Bool {
        backends.contains { $0.isConnected }
    }

    // MARK: - Backend Management

    func addBackend(_ backend: any SmartHomeBackend) {
        backends.append(backend)
    }

    func connectHue() async throws {
        if !backends.contains(where: { $0.backendType == .hue }) {
            backends.append(hueBackend)
        }
        try await hueBackend.connect()
        await refreshLights()
    }

    func disconnectHue() {
        hueBackend.disconnect()
        backends.removeAll { $0.backendType == .hue }
        removeLights(for: .hue)
    }

    func connectHueBluetooth() async throws {
        let backend = HueBluetoothBackend()
        hueBluetoothBackend = backend
        if !backends.contains(where: { $0.backendType == .hueBluetooth }) {
            backends.append(backend)
        }
        try await backend.connect()
        await refreshLights()
    }

    func disconnectHueBluetooth() {
        hueBluetoothBackend?.disconnect()
        hueBluetoothBackend = nil
        backends.removeAll { $0.backendType == .hueBluetooth }
        removeLights(for: .hueBluetooth)
    }

    func connectHomeKit() async throws {
        let backend = HomeKitBackend()
        homeKitBackend = backend
        if !backends.contains(where: { $0.backendType == .homekit }) {
            backends.append(backend)
        }
        try await backend.connect()
        await refreshLights()
    }

    func disconnectHomeKit() {
        homeKitBackend?.disconnect()
        homeKitBackend = nil
        backends.removeAll { $0.backendType == .homekit }
        removeLights(for: .homekit)
    }

    // MARK: - Light Discovery

    func refreshLights() async {
        isRefreshing = true
        defer { isRefreshing = false }

        var allLights: [SmartLight] = []
        for backend in backends where backend.isConnected {
            do {
                let discovered = try await backend.discoverLights()
                allLights.append(contentsOf: discovered)
            } catch {
                Logger.app.error("Failed to discover lights from \(backend.backendType.rawValue): \(error)")
            }
        }

        lights = allLights
        commands = SmartHomeCommandGenerator.generateCommands(from: allLights)
        Logger.app.info("Discovered \(allLights.count) lights, generated \(self.commands.count) commands")
    }

    private func removeLights(for type: SmartHomeBackendType) {
        lights.removeAll { $0.backend == type }
        commands = SmartHomeCommandGenerator.generateCommands(from: lights)
    }

    // MARK: - Command Matching & Execution

    /// Check if text matches a smart home command and execute it.
    /// Returns true if a command was matched and executed (text should NOT be inserted).
    func tryExecuteCommand(text: String) async -> Bool {
        guard hasAnyConnection, !commands.isEmpty else { return false }

        guard let result = SmartHomeCommandMatcher.match(text: text, commands: commands) else {
            return false
        }

        do {
            try await executeAction(result)
            lastActionMessage = actionDescription(result)
            Logger.app.info("Smart home action: \(self.lastActionMessage ?? "")")
            return true
        } catch {
            Logger.app.error("Smart home action failed: \(error)")
            lastActionMessage = "Failed: \(error.localizedDescription)"
            return false
        }
    }

    private func executeAction(_ result: SmartHomeMatchResult) async throws {
        let command = result.command

        // Find the right backend for this light
        guard let backend = backendForLight(id: command.targetLightId) else {
            throw SmartHomeServiceError.noBackendForLight
        }

        let stateChange: LightStateChange
        switch command.action {
        case .turnOn:
            stateChange = LightStateChange(on: true)
        case .turnOff:
            stateChange = LightStateChange(on: false)
        case .setBrightness:
            let brightness = result.parsedBrightness ?? 50
            stateChange = LightStateChange(on: true, brightness: brightness)
        case .dim:
            let current = lights.first { $0.id == command.targetLightId }?.brightness ?? 50
            stateChange = LightStateChange(on: true, brightness: max(0, current - 25))
        case .brighten:
            let current = lights.first { $0.id == command.targetLightId }?.brightness ?? 50
            stateChange = LightStateChange(on: true, brightness: min(100, current + 25))
        case .fullBrightness:
            stateChange = LightStateChange(on: true, brightness: 100)
        }

        if command.isRoomLevel {
            // Apply to all lights in the same room
            let roomName = lights.first { $0.id == command.targetLightId }?.roomName
            if let roomName {
                let roomLights = lights.filter { $0.roomName == roomName && $0.backend == backend.backendType }
                for light in roomLights {
                    try await backend.setLightState(id: light.id, state: stateChange)
                }
            }
        } else {
            try await backend.setLightState(id: command.targetLightId, state: stateChange)
        }

        // Refresh state after action
        await refreshLights()
    }

    private func backendForLight(id: String) -> (any SmartHomeBackend)? {
        guard let light = lights.first(where: { $0.id == id }) else { return nil }
        return backends.first { $0.backendType == light.backend }
    }

    private func actionDescription(_ result: SmartHomeMatchResult) -> String {
        let name = result.command.targetName
        switch result.command.action {
        case .turnOn: return "\(name) on"
        case .turnOff: return "\(name) off"
        case .setBrightness: return "\(name) set to \(result.parsedBrightness ?? 0)%"
        case .dim: return "\(name) dimmed"
        case .brighten: return "\(name) brightened"
        case .fullBrightness: return "\(name) full brightness"
        }
    }
}

enum SmartHomeServiceError: LocalizedError {
    case noBackendForLight

    var errorDescription: String? {
        switch self {
        case .noBackendForLight: return "No backend available for this light"
        }
    }
}
