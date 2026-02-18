import Foundation

@MainActor
@Observable
final class IntegrationsViewModel {
    let smartHomeService: SmartHomeService

    var isConnectingHue = false
    var isConnectingHueBluetooth = false
    var isConnectingHomeKit = false
    var errorMessage: String?

    var hueBackend: HueBridgeBackend { smartHomeService.hueBackend }

    var lights: [SmartLight] { smartHomeService.lights }
    var commands: [SmartHomeCommand] { smartHomeService.commands }
    var isRefreshing: Bool { smartHomeService.isRefreshing }

    var isHueConnected: Bool { hueBackend.isConnected }
    var isHueBluetoothConnected: Bool { smartHomeService.hueBluetoothBackend?.isConnected ?? false }
    var isHomeKitConnected: Bool { smartHomeService.homeKitBackend?.isConnected ?? false }

    var huePairingState: HueBridgeBackend.PairingState { hueBackend.pairingState }

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

    func connectHomeKit() async {
        isConnectingHomeKit = true
        errorMessage = nil
        do {
            try await smartHomeService.connectHomeKit()
        } catch {
            errorMessage = error.localizedDescription
        }
        isConnectingHomeKit = false
    }

    func disconnectHomeKit() {
        smartHomeService.disconnectHomeKit()
    }

    func refreshLights() async {
        await smartHomeService.refreshLights()
    }

    /// Grouped lights by room for display
    var lightsByRoom: [(room: String, lights: [SmartLight])] {
        let grouped = Dictionary(grouping: lights, by: { $0.roomName ?? "Other" })
        return grouped.sorted { $0.key < $1.key }.map { (room: $0.key, lights: $0.value) }
    }
}
