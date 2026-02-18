import Foundation
import os

#if canImport(HomeKit)
import HomeKit

/// Apple HomeKit backend for smart home control
@MainActor
final class HomeKitBackend: NSObject, SmartHomeBackend {
    let backendType: SmartHomeBackendType = .homekit

    private(set) var isConnected = false
    private var homeManager: HMHomeManager?
    private var delegate: HomeKitDelegate?

    func connect() async throws {
        delegate = HomeKitDelegate()
        let manager = HMHomeManager()
        manager.delegate = delegate
        homeManager = manager

        // Wait for initial home data to load
        try await delegate!.waitForInitialLoad()
        isConnected = true
        Logger.app.info("HomeKit connected with \(manager.homes.count) homes")
    }

    func disconnect() {
        homeManager = nil
        delegate = nil
        isConnected = false
    }

    func discoverLights() async throws -> [SmartLight] {
        guard let manager = homeManager else { throw HomeKitError.notConnected }

        var lights: [SmartLight] = []

        for home in manager.homes {
            for room in home.rooms {
                for accessory in room.accessories {
                    for service in accessory.services where service.serviceType == HMServiceTypeLightbulb {
                        let isOn = boolCharacteristic(service, type: HMCharacteristicTypePowerState) ?? false
                        let brightness = intCharacteristic(service, type: HMCharacteristicTypeBrightness) ?? 0

                        lights.append(SmartLight(
                            id: service.uniqueIdentifier.uuidString,
                            name: accessory.name,
                            roomName: room.name,
                            isOn: isOn,
                            brightness: brightness,
                            isReachable: accessory.isReachable,
                            backend: .homekit
                        ))
                    }
                }
            }
        }

        return lights
    }

    func setLightState(id: String, state: LightStateChange) async throws {
        guard let manager = homeManager else { throw HomeKitError.notConnected }

        guard let service = findService(id: id, in: manager) else {
            throw HomeKitError.deviceNotFound
        }

        if let on = state.on {
            if let characteristic = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypePowerState }) {
                try await characteristic.writeValue(on)
            }
        }

        if let brightness = state.brightness {
            if let characteristic = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypeBrightness }) {
                try await characteristic.writeValue(brightness)
            }
        }
    }

    // MARK: - Helpers

    private func findService(id: String, in manager: HMHomeManager) -> HMService? {
        for home in manager.homes {
            for room in home.rooms {
                for accessory in room.accessories {
                    for service in accessory.services where service.uniqueIdentifier.uuidString == id {
                        return service
                    }
                }
            }
        }
        return nil
    }

    private func boolCharacteristic(_ service: HMService, type: String) -> Bool? {
        service.characteristics.first { $0.characteristicType == type }?.value as? Bool
    }

    private func intCharacteristic(_ service: HMService, type: String) -> Int? {
        service.characteristics.first { $0.characteristicType == type }?.value as? Int
    }
}

// MARK: - Delegate

private class HomeKitDelegate: NSObject, HMHomeManagerDelegate {
    private var continuation: CheckedContinuation<Void, Error>?
    private var hasLoaded = false

    func waitForInitialLoad() async throws {
        if hasLoaded { return }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.continuation = cont

            // Timeout after 10 seconds
            Task {
                try? await Task.sleep(for: .seconds(10))
                if !self.hasLoaded {
                    self.hasLoaded = true
                    cont.resume(throwing: HomeKitError.timeout)
                }
            }
        }
    }

    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        guard !hasLoaded else { return }
        hasLoaded = true
        continuation?.resume()
        continuation = nil
    }
}

#else

/// Stub HomeKit backend when HomeKit framework is not available
@MainActor
final class HomeKitBackend: SmartHomeBackend {
    let backendType: SmartHomeBackendType = .homekit
    var isConnected: Bool { false }

    func connect() async throws {
        throw HomeKitError.notAvailable
    }

    func disconnect() {}

    func discoverLights() async throws -> [SmartLight] { [] }

    func setLightState(id: String, state: LightStateChange) async throws {
        throw HomeKitError.notAvailable
    }
}

#endif

enum HomeKitError: LocalizedError {
    case notConnected
    case deviceNotFound
    case timeout
    case notAvailable

    var errorDescription: String? {
        switch self {
        case .notConnected: return "HomeKit not connected"
        case .deviceNotFound: return "Device not found"
        case .timeout: return "HomeKit timed out loading homes"
        case .notAvailable: return "HomeKit is not available on this system"
        }
    }
}
