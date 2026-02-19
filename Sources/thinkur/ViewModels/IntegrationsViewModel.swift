import Foundation

@MainActor
@Observable
final class IntegrationsViewModel {
    let smartHomeService: SmartHomeService

    var isConnectingHue = false
    var isConnectingHueBluetooth = false
    var errorMessage: String?

    var hueBackend: HueBridgeBackend { smartHomeService.hueBackend }

    var lights: [SmartLight] { smartHomeService.lights }
    var commands: [SmartHomeCommand] { smartHomeService.commands }
    var isRefreshing: Bool { smartHomeService.isRefreshing }

    var isHueConnected: Bool { hueBackend.isConnected }
    var isHueBluetoothConnected: Bool { smartHomeService.hueBluetoothBackend?.isConnected ?? false }

    var huePairingState: HueBridgeBackend.PairingState { hueBackend.pairingState }

    /// Active debounce tasks keyed by light ID
    private var brightnessTasks: [String: Task<Void, Never>] = [:]
    private var colorTempTasks: [String: Task<Void, Never>] = [:]

    init(smartHomeService: SmartHomeService) {
        self.smartHomeService = smartHomeService
    }

    func connectHue() async {
        isConnectingHue = true
        errorMessage = nil
        do {
            try await smartHomeService.connectHue()
        } catch {
            errorMessage = error.localizedDescription
        }
        isConnectingHue = false
    }

    func disconnectHue() {
        smartHomeService.disconnectHue()
    }

    func connectHueBluetooth() async {
        isConnectingHueBluetooth = true
        errorMessage = nil
        do {
            try await smartHomeService.connectHueBluetooth()
        } catch {
            errorMessage = error.localizedDescription
        }
        isConnectingHueBluetooth = false
    }

    func disconnectHueBluetooth() {
        smartHomeService.disconnectHueBluetooth()
    }

    func refreshLights() async {
        await smartHomeService.refreshLights()
    }

    // MARK: - Light Controls

    /// Toggle a light on/off with optimistic update
    func toggleLight(id: String, on: Bool) {
        smartHomeService.updateLightOptimistically(id: id, isOn: on)
        Task {
            do {
                try await smartHomeService.setLightState(id: id, state: LightStateChange(on: on))
            } catch {
                errorMessage = error.localizedDescription
                await smartHomeService.refreshLights()
            }
        }
    }

    /// Set brightness with optimistic update and debounced backend call
    func setBrightness(id: String, brightness: Int) {
        smartHomeService.updateLightOptimistically(id: id, brightness: brightness)

        // Cancel previous debounce for this light
        brightnessTasks[id]?.cancel()

        brightnessTasks[id] = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            do {
                try await smartHomeService.setLightState(id: id, state: LightStateChange(on: true, brightness: brightness))
            } catch {
                errorMessage = error.localizedDescription
                await smartHomeService.refreshLights()
            }
        }
    }

    /// Set color temperature with optimistic update and debounced backend call
    func setColorTemperature(id: String, mirek: Int) {
        smartHomeService.updateLightOptimistically(id: id, colorTemperature: mirek)

        colorTempTasks[id]?.cancel()

        colorTempTasks[id] = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            do {
                try await smartHomeService.setLightState(id: id, state: LightStateChange(colorTemperature: mirek))
            } catch {
                errorMessage = error.localizedDescription
                await smartHomeService.refreshLights()
            }
        }
    }

    /// Grouped lights by room for display
    var lightsByRoom: [(room: String, lights: [SmartLight])] {
        let grouped = Dictionary(grouping: lights, by: { $0.roomName ?? "Other" })
        return grouped.sorted { $0.key < $1.key }.map { (room: $0.key, lights: $0.value) }
    }
}
