import CoreBluetooth
import Foundation
import os

/// Philips Hue Bluetooth Low Energy backend — direct bulb control, no bridge needed.
///
/// Uses the Hue BLE Light Control Service (reverse-engineered) to communicate
/// with Hue bulbs via CoreBluetooth. Supports power, brightness, and color
/// through TLV commands on characteristic 0007.
///
/// Limits: ~10 bulbs max, ~30ft/10m range.
@MainActor
final class HueBluetoothBackend: NSObject, SmartHomeBackend {
    let backendType: SmartHomeBackendType = .hueBluetooth

    private(set) var isConnected = false

    private var centralManager: CBCentralManager?
    private var bleDelegate: HueBluetoothDelegate?

    /// Connected peripherals keyed by their identifier UUID string.
    private var peripherals: [String: CBPeripheral] = [:]
    /// Control characteristic (0007) for each peripheral, keyed by peripheral identifier.
    private var controlCharacteristics: [String: CBCharacteristic] = [:]
    /// Power characteristic (0002) for reading on/off state.
    private var powerCharacteristics: [String: CBCharacteristic] = [:]
    /// Brightness characteristic (0003) for reading brightness.
    private var brightnessCharacteristics: [String: CBCharacteristic] = [:]

    func connect() async throws {
        bleDelegate = HueBluetoothDelegate()
        let delegate = bleDelegate!

        // Create the central manager — this triggers a state update callback
        let manager = CBCentralManager(delegate: delegate, queue: nil)
        centralManager = manager

        // Wait for Bluetooth to power on
        Logger.bluetooth.info("Waiting for Bluetooth to power on…")
        try await delegate.waitForPoweredOn()
        Logger.bluetooth.info("Bluetooth powered on")

        // Scan for Hue BLE bulbs (5s to allow for slow advertisement intervals)
        Logger.bluetooth.info("Starting scan for Hue BLE bulbs…")
        let discovered = try await delegate.scanForHueBulbs(manager: manager, timeout: 5.0)

        guard !discovered.isEmpty else {
            isConnected = false
            throw HueBluetoothError.noBulbsFound
        }

        Logger.bluetooth.info("Found \(discovered.count) Hue bulb(s), connecting…")

        // Connect to each discovered peripheral and discover characteristics
        for peripheral in discovered {
            let key = peripheral.identifier.uuidString
            peripherals[key] = peripheral

            Logger.bluetooth.info("Connecting to \(peripheral.name ?? "Unknown") (\(key))")
            let characteristics = try await delegate.connectAndDiscover(
                manager: manager,
                peripheral: peripheral
            )

            if let control = characteristics.control {
                controlCharacteristics[key] = control
            }
            if let power = characteristics.power {
                powerCharacteristics[key] = power
            }
            if let brightness = characteristics.brightness {
                brightnessCharacteristics[key] = brightness
            }
            Logger.bluetooth.info("Discovered characteristics for \(peripheral.name ?? "Unknown"): control=\(characteristics.control != nil), power=\(characteristics.power != nil), brightness=\(characteristics.brightness != nil)")
        }

        isConnected = true
        Logger.bluetooth.info("Hue BLE connected with \(self.peripherals.count) bulb(s)")
    }

    func disconnect() {
        if let manager = centralManager {
            manager.stopScan()
            for peripheral in peripherals.values {
                manager.cancelPeripheralConnection(peripheral)
            }
        }
        peripherals.removeAll()
        controlCharacteristics.removeAll()
        powerCharacteristics.removeAll()
        brightnessCharacteristics.removeAll()
        centralManager = nil
        bleDelegate = nil
        isConnected = false
    }

    func discoverLights() async throws -> [SmartLight] {
        peripherals.map { key, peripheral in
            let isOn = readPowerState(for: key)
            let brightness = readBrightness(for: key)

            return SmartLight(
                id: "huebt-\(key)",
                name: peripheral.name ?? "Hue Bulb",
                roomName: nil,
                isOn: isOn,
                brightness: brightness,
                isReachable: peripheral.state == .connected,
                backend: .hueBluetooth
            )
        }
    }

    func setLightState(id: String, state: LightStateChange) async throws {
        // Strip the "huebt-" prefix to get the peripheral key
        let key = String(id.dropFirst("huebt-".count))

        guard let characteristic = controlCharacteristics[key] else {
            throw HueBluetoothError.characteristicNotFound
        }
        guard let peripheral = peripherals[key] else {
            throw HueBluetoothError.peripheralNotFound
        }

        // Build TLV command and write
        if let on = state.on {
            let data = on ? Self.buildTLVOn() : Self.buildTLVOff()
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        }

        if let brightness = state.brightness {
            let data = Self.buildTLVBrightness(percent: brightness)
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        }
    }

    // MARK: - TLV Command Builders (static for testability)

    /// TLV command to turn on: type=0x01, length=0x01, value=0x01
    nonisolated static func buildTLVOn() -> Data {
        Data([0x01, 0x01, 0x01])
    }

    /// TLV command to turn off: type=0x01, length=0x01, value=0x00
    nonisolated static func buildTLVOff() -> Data {
        Data([0x01, 0x01, 0x00])
    }

    /// TLV command to set brightness: type=0x02, length=0x01, value=scaled 0-254
    /// - Parameter percent: Brightness 0-100
    nonisolated static func buildTLVBrightness(percent: Int) -> Data {
        let clamped = max(0, min(100, percent))
        let scaled = UInt8(clamped * 254 / 100)
        return Data([0x02, 0x01, scaled])
    }

    // MARK: - State Reading

    private func readPowerState(for key: String) -> Bool {
        guard let characteristic = powerCharacteristics[key],
              let value = characteristic.value,
              !value.isEmpty else { return false }
        return value[0] != 0
    }

    private func readBrightness(for key: String) -> Int {
        guard let characteristic = brightnessCharacteristics[key],
              let value = characteristic.value,
              !value.isEmpty else { return 0 }
        // Scale 0-254 back to 0-100
        return Int(value[0]) * 100 / 254
    }
}

// MARK: - BLE UUIDs

/// Signify (Philips Hue) registered BLE advertisement UUID.
/// Hue bulbs advertise this in service data — used for discovery filtering.
private let hueAdvertisementUUID = CBUUID(string: "FE0F")

/// Post-connection GATT service and characteristic UUIDs (not advertised).
private let lightControlServiceUUID = CBUUID(string: "932c32bd-0000-47a2-835a-a8d455b859dd")
private let powerCharacteristicUUID = CBUUID(string: "932c32bd-0002-47a2-835a-a8d455b859dd")
private let brightnessCharacteristicUUID = CBUUID(string: "932c32bd-0003-47a2-835a-a8d455b859dd")
private let controlCharacteristicUUID = CBUUID(string: "932c32bd-0007-47a2-835a-a8d455b859dd")

// MARK: - Delegate (bridges CB callbacks → async/await)

private class HueBluetoothDelegate: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var stateContinuation: CheckedContinuation<Void, Error>?
    private var scanContinuation: CheckedContinuation<[CBPeripheral], Error>?
    private var connectContinuation: CheckedContinuation<Void, Error>?
    private var servicesContinuation: CheckedContinuation<Void, Error>?
    private var characteristicsContinuation: CheckedContinuation<Void, Error>?

    private var discoveredPeripherals: [CBPeripheral] = []
    private var isPoweredOn = false

    struct DiscoveredCharacteristics {
        var control: CBCharacteristic?
        var power: CBCharacteristic?
        var brightness: CBCharacteristic?
    }

    private var lastDiscoveredCharacteristics = DiscoveredCharacteristics()

    // MARK: - Async Helpers

    func waitForPoweredOn() async throws {
        if isPoweredOn { return }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            stateContinuation = cont

            Task {
                try? await Task.sleep(for: .seconds(5))
                if !isPoweredOn {
                    isPoweredOn = false
                    stateContinuation?.resume(throwing: HueBluetoothError.bluetoothNotAvailable)
                    stateContinuation = nil
                }
            }
        }
    }

    func scanForHueBulbs(manager: CBCentralManager, timeout: Double) async throws -> [CBPeripheral] {
        discoveredPeripherals = []

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[CBPeripheral], Error>) in
            scanContinuation = cont

            // Scan with nil services — FE0F may appear in service data rather than
            // advertised service UUIDs, so we filter in didDiscover instead.
            manager.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )

            Task {
                try? await Task.sleep(for: .seconds(timeout))
                manager.stopScan()
                Logger.bluetooth.info("Scan complete, found \(self.discoveredPeripherals.count) Hue bulb(s)")
                let peripherals = self.discoveredPeripherals
                self.scanContinuation?.resume(returning: peripherals)
                self.scanContinuation = nil
            }
        }
    }

    func connectAndDiscover(
        manager: CBCentralManager,
        peripheral: CBPeripheral
    ) async throws -> DiscoveredCharacteristics {
        peripheral.delegate = self
        lastDiscoveredCharacteristics = DiscoveredCharacteristics()

        // Connect
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connectContinuation = cont
            manager.connect(peripheral, options: nil)

            Task {
                try? await Task.sleep(for: .seconds(5))
                self.connectContinuation?.resume(throwing: HueBluetoothError.connectionTimeout)
                self.connectContinuation = nil
            }
        }

        // Discover services
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            servicesContinuation = cont
            peripheral.discoverServices([lightControlServiceUUID])

            Task {
                try? await Task.sleep(for: .seconds(5))
                self.servicesContinuation?.resume(throwing: HueBluetoothError.discoveryTimeout)
                self.servicesContinuation = nil
            }
        }

        // Discover characteristics
        guard let service = peripheral.services?.first(where: { $0.uuid == lightControlServiceUUID }) else {
            throw HueBluetoothError.serviceNotFound
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            characteristicsContinuation = cont
            peripheral.discoverCharacteristics(
                [powerCharacteristicUUID, brightnessCharacteristicUUID, controlCharacteristicUUID],
                for: service
            )

            Task {
                try? await Task.sleep(for: .seconds(5))
                self.characteristicsContinuation?.resume(throwing: HueBluetoothError.discoveryTimeout)
                self.characteristicsContinuation = nil
            }
        }

        // Read initial values — macOS may prompt for Bluetooth pairing here
        Logger.bluetooth.info("Reading characteristics — macOS may prompt for Bluetooth pairing")
        if let power = lastDiscoveredCharacteristics.power {
            peripheral.readValue(for: power)
        }
        if let brightness = lastDiscoveredCharacteristics.brightness {
            peripheral.readValue(for: brightness)
        }

        return lastDiscoveredCharacteristics
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Logger.bluetooth.info("Bluetooth state: \(String(describing: central.state.rawValue))")
        if central.state == .poweredOn {
            isPoweredOn = true
            stateContinuation?.resume()
            stateContinuation = nil
        } else if central.state == .unsupported || central.state == .unauthorized || central.state == .poweredOff {
            Logger.bluetooth.warning("Bluetooth unavailable (state=\(central.state.rawValue))")
            stateContinuation?.resume(throwing: HueBluetoothError.bluetoothNotAvailable)
            stateContinuation = nil
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard isHueBulb(advertisementData) else { return }

        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)
            Logger.bluetooth.info("Discovered Hue BLE bulb: \(peripheral.name ?? "Unknown") (\(peripheral.identifier)), RSSI=\(RSSI)")
        }
    }

    /// Check if advertisement data contains the Signify (Hue) UUID `0xFE0F`.
    private func isHueBulb(_ advertisementData: [String: Any]) -> Bool {
        // Check service data (primary signal — Hue bulbs advertise FE0F here)
        if let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data],
           serviceData.keys.contains(hueAdvertisementUUID) {
            return true
        }
        // Check advertised service UUIDs (secondary signal)
        if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID],
           serviceUUIDs.contains(hueAdvertisementUUID) {
            return true
        }
        return false
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Logger.bluetooth.info("Connected to \(peripheral.name ?? "Unknown")")
        connectContinuation?.resume()
        connectContinuation = nil
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Logger.bluetooth.error("Failed to connect to \(peripheral.name ?? "Unknown"): \(error?.localizedDescription ?? "unknown error")")
        connectContinuation?.resume(throwing: error ?? HueBluetoothError.connectionFailed)
        connectContinuation = nil
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            Logger.bluetooth.error("Service discovery failed for \(peripheral.name ?? "Unknown"): \(error.localizedDescription)")
            servicesContinuation?.resume(throwing: error)
        } else {
            let uuids = peripheral.services?.map(\.uuid.uuidString) ?? []
            Logger.bluetooth.info("Discovered services on \(peripheral.name ?? "Unknown"): \(uuids)")
            servicesContinuation?.resume()
        }
        servicesContinuation = nil
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if let error {
            characteristicsContinuation?.resume(throwing: error)
            characteristicsContinuation = nil
            return
        }

        for characteristic in service.characteristics ?? [] {
            switch characteristic.uuid {
            case controlCharacteristicUUID:
                lastDiscoveredCharacteristics.control = characteristic
            case powerCharacteristicUUID:
                lastDiscoveredCharacteristics.power = characteristic
            case brightnessCharacteristicUUID:
                lastDiscoveredCharacteristics.brightness = characteristic
            default:
                break
            }
        }

        characteristicsContinuation?.resume()
        characteristicsContinuation = nil
    }
}

// MARK: - Errors

enum HueBluetoothError: LocalizedError {
    case bluetoothNotAvailable
    case noBulbsFound
    case connectionTimeout
    case connectionFailed
    case discoveryTimeout
    case serviceNotFound
    case characteristicNotFound
    case peripheralNotFound

    var errorDescription: String? {
        switch self {
        case .bluetoothNotAvailable: return "Bluetooth is not available or not authorized"
        case .noBulbsFound: return "No Hue Bluetooth bulbs found nearby. Make sure the bulb is powered on and in pairing mode (factory reset or use the Hue app: Settings > Voice Assistants > Make visible)."
        case .connectionTimeout: return "Connection to bulb timed out"
        case .connectionFailed: return "Failed to connect to bulb"
        case .discoveryTimeout: return "Service discovery timed out"
        case .serviceNotFound: return "Hue light control service not found on bulb"
        case .characteristicNotFound: return "Control characteristic not found"
        case .peripheralNotFound: return "Bulb not found"
        }
    }
}
