import CoreBluetooth
import Foundation
import os

/// Philips Hue Bluetooth Low Energy backend — direct bulb control, no bridge needed.
///
/// Writes directly to individual GATT characteristics:
/// - Power (0002): `[0x01]` on, `[0x00]` off
/// - Brightness (0003): `[UInt8]` scaled 0-254
///
/// Requires BLE bonding (encryption). On first connect, the bulb must be in
/// pairing mode (Hue app → Settings → Voice Assistants → Make Discoverable).
/// Reading an encrypted characteristic triggers macOS's pairing dialog.
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
    /// Power characteristic (0002) for on/off control and state.
    private var powerCharacteristics: [String: CBCharacteristic] = [:]
    /// Brightness characteristic (0003) for brightness control and state.
    private var brightnessCharacteristics: [String: CBCharacteristic] = [:]
    /// Color temperature characteristic (0004) in mirek (153-500).
    private var colorTempCharacteristics: [String: CBCharacteristic] = [:]

    func connect() async throws {
        bleDelegate = HueBluetoothDelegate()
        let delegate = bleDelegate!

        let manager = CBCentralManager(delegate: delegate, queue: nil)
        centralManager = manager

        Logger.bluetooth.info("Waiting for Bluetooth to power on…")
        try await delegate.waitForPoweredOn()
        Logger.bluetooth.info("Bluetooth powered on")

        Logger.bluetooth.info("Starting scan for Hue BLE bulbs…")
        let discovered = try await delegate.scanForHueBulbs(manager: manager, timeout: 5.0)

        guard !discovered.isEmpty else {
            isConnected = false
            throw HueBluetoothError.noBulbsFound
        }

        Logger.bluetooth.info("Found \(discovered.count) Hue bulb(s), connecting…")

        for peripheral in discovered {
            let key = peripheral.identifier.uuidString
            peripherals[key] = peripheral

            Logger.bluetooth.info("Connecting to \(peripheral.name ?? "Unknown") (\(key))")
            let characteristics = try await delegate.connectAndDiscover(
                manager: manager,
                peripheral: peripheral
            )

            if let power = characteristics.power {
                powerCharacteristics[key] = power
            }
            if let brightness = characteristics.brightness {
                brightnessCharacteristics[key] = brightness
            }
            if let colorTemp = characteristics.colorTemperature {
                colorTempCharacteristics[key] = colorTemp
            }
            Logger.bluetooth.info("Discovered characteristics for \(peripheral.name ?? "Unknown"): power=\(characteristics.power != nil), brightness=\(characteristics.brightness != nil), colorTemp=\(characteristics.colorTemperature != nil), paired=\(characteristics.isPaired)")

            if !characteristics.isPaired {
                Logger.bluetooth.warning("Bulb not paired — user must put bulb in pairing mode first")
            }
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
        powerCharacteristics.removeAll()
        brightnessCharacteristics.removeAll()
        colorTempCharacteristics.removeAll()
        centralManager = nil
        bleDelegate = nil
        isConnected = false
    }

    func discoverLights() async throws -> [SmartLight] {
        peripherals.map { key, peripheral in
            let isOn = readPowerState(for: key)
            let brightness = readBrightness(for: key)
            let colorTemp = readColorTemperature(for: key)

            return SmartLight(
                id: "huebt-\(key)",
                name: peripheral.name ?? "Hue Bulb",
                roomName: nil,
                isOn: isOn,
                brightness: brightness,
                colorTemperature: colorTemp,
                isReachable: peripheral.state == .connected,
                backend: .hueBluetooth
            )
        }
    }

    func setLightState(id: String, state: LightStateChange) async throws {
        let key = String(id.dropFirst("huebt-".count))

        guard let peripheral = peripherals[key] else {
            throw HueBluetoothError.peripheralNotFound
        }
        guard let delegate = bleDelegate else {
            throw HueBluetoothError.connectionFailed
        }

        if let on = state.on {
            guard let power = powerCharacteristics[key] else {
                throw HueBluetoothError.characteristicNotFound
            }
            let data = Data([on ? 0x01 : 0x00])
            try await delegate.writeCharacteristicValue(
                peripheral: peripheral, characteristic: power, data: data
            )
        }

        if let brightness = state.brightness {
            guard let bright = brightnessCharacteristics[key] else {
                throw HueBluetoothError.characteristicNotFound
            }
            let clamped = max(0, min(100, brightness))
            let scaled = UInt8(clamped * 254 / 100)
            let data = Data([scaled])
            try await delegate.writeCharacteristicValue(
                peripheral: peripheral, characteristic: bright, data: data
            )
        }

        if let colorTemp = state.colorTemperature {
            guard let ct = colorTempCharacteristics[key] else {
                throw HueBluetoothError.characteristicNotFound
            }
            let clamped = UInt16(max(153, min(500, colorTemp)))
            var value = clamped.littleEndian
            let data = Data(bytes: &value, count: 2)
            try await delegate.writeCharacteristicValue(
                peripheral: peripheral, characteristic: ct, data: data
            )
        }
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
        return Int(value[0]) * 100 / 254
    }

    private func readColorTemperature(for key: String) -> Int? {
        guard let characteristic = colorTempCharacteristics[key],
              let value = characteristic.value,
              value.count >= 2 else { return nil }
        let mirek = UInt16(value[0]) | (UInt16(value[1]) << 8)  // little-endian
        return Int(mirek)
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
private let colorTemperatureCharacteristicUUID = CBUUID(string: "932c32bd-0004-47a2-835a-a8d455b859dd")

// MARK: - Delegate (bridges CB callbacks → async/await)

private class HueBluetoothDelegate: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var stateContinuation: CheckedContinuation<Void, Error>?
    private var scanContinuation: CheckedContinuation<[CBPeripheral], Error>?
    private var connectContinuation: CheckedContinuation<Void, Error>?
    private var servicesContinuation: CheckedContinuation<Void, Error>?
    private var characteristicsContinuation: CheckedContinuation<Void, Error>?
    private var readValueContinuation: CheckedContinuation<Void, Error>?
    private var writeValueContinuation: CheckedContinuation<Void, Error>?
    private var notifyContinuation: CheckedContinuation<Void, Error>?

    private var discoveredPeripherals: [CBPeripheral] = []
    private var isPoweredOn = false

    struct DiscoveredCharacteristics {
        var power: CBCharacteristic?
        var brightness: CBCharacteristic?
        var colorTemperature: CBCharacteristic?
        var isPaired = false
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

    func readCharacteristicValue(
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        timeout: Double = 10
    ) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            readValueContinuation = cont
            peripheral.readValue(for: characteristic)

            Task {
                try? await Task.sleep(for: .seconds(timeout))
                self.readValueContinuation?.resume(throwing: HueBluetoothError.discoveryTimeout)
                self.readValueContinuation = nil
            }
        }
    }

    /// Write with `.withResponse` and await the `didWriteValueFor` callback.
    /// If we get an encryption error on the first attempt, wait for macOS pairing
    /// dialog and retry once.
    func writeCharacteristicValue(
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        data: Data
    ) async throws {
        for attempt in 1...2 {
            do {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    self.writeValueContinuation = cont
                    peripheral.writeValue(data, for: characteristic, type: .withResponse)

                    Task {
                        try? await Task.sleep(for: .seconds(10))
                        self.writeValueContinuation?.resume(throwing: HueBluetoothError.discoveryTimeout)
                        self.writeValueContinuation = nil
                    }
                }
                return
            } catch {
                let nsError = error as NSError
                let isEncryptionError = nsError.domain == CBATTErrorDomain
                    && (nsError.code == CBATTError.insufficientEncryption.rawValue
                        || nsError.code == CBATTError.insufficientAuthentication.rawValue)

                if isEncryptionError && attempt == 1 {
                    Logger.bluetooth.info("Write needs encryption — waiting for macOS pairing dialog…")
                    try? await Task.sleep(for: .seconds(8))
                    Logger.bluetooth.info("Retrying write after pairing wait…")
                    continue
                }

                if isEncryptionError {
                    throw HueBluetoothError.pairingRequired
                }
                throw error
            }
        }
    }

    /// Subscribe to notifications on a characteristic.
    func subscribeToCharacteristic(peripheral: CBPeripheral, characteristic: CBCharacteristic) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            notifyContinuation = cont
            peripheral.setNotifyValue(true, for: characteristic)

            Task {
                try? await Task.sleep(for: .seconds(10))
                self.notifyContinuation?.resume(throwing: HueBluetoothError.discoveryTimeout)
                self.notifyContinuation = nil
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
                [powerCharacteristicUUID, brightnessCharacteristicUUID, colorTemperatureCharacteristicUUID],
                for: service
            )

            Task {
                try? await Task.sleep(for: .seconds(5))
                self.characteristicsContinuation?.resume(throwing: HueBluetoothError.discoveryTimeout)
                self.characteristicsContinuation = nil
            }
        }

        // Trigger pairing — reading an encrypted characteristic forces macOS to
        // show the Bluetooth pairing dialog if the bulb is accepting new bonds.
        // We use a generous 20s timeout so the user has time to accept.
        if let power = lastDiscoveredCharacteristics.power {
            Logger.bluetooth.info("Reading power characteristic to trigger pairing — if a macOS Bluetooth pairing dialog appears, please accept it…")
            do {
                try await readCharacteristicValue(
                    peripheral: peripheral,
                    characteristic: power,
                    timeout: 20
                )
                Logger.bluetooth.info("Power state read succeeded — encryption established")
                lastDiscoveredCharacteristics.isPaired = true

                // Subscribe to notifications for real-time state updates
                do {
                    try await subscribeToCharacteristic(peripheral: peripheral, characteristic: power)
                    Logger.bluetooth.info("Subscribed to power notifications")
                } catch {
                    Logger.bluetooth.warning("Power notification subscription failed: \(error.localizedDescription)")
                }
            } catch {
                Logger.bluetooth.warning("Power read failed — bulb may not be in pairing mode: \(error.localizedDescription)")
            }
        }

        if let brightness = lastDiscoveredCharacteristics.brightness {
            do {
                try await readCharacteristicValue(peripheral: peripheral, characteristic: brightness)
                Logger.bluetooth.info("Brightness state read succeeded")

                // Subscribe to brightness notifications too
                if lastDiscoveredCharacteristics.isPaired {
                    do {
                        try await subscribeToCharacteristic(peripheral: peripheral, characteristic: brightness)
                        Logger.bluetooth.info("Subscribed to brightness notifications")
                    } catch {
                        Logger.bluetooth.warning("Brightness notification subscription failed: \(error.localizedDescription)")
                    }
                }
            } catch {
                Logger.bluetooth.warning("Brightness read failed: \(error.localizedDescription)")
            }
        }

        if let colorTemp = lastDiscoveredCharacteristics.colorTemperature {
            do {
                try await readCharacteristicValue(peripheral: peripheral, characteristic: colorTemp)
                Logger.bluetooth.info("Color temperature state read succeeded")

                if lastDiscoveredCharacteristics.isPaired {
                    do {
                        try await subscribeToCharacteristic(peripheral: peripheral, characteristic: colorTemp)
                        Logger.bluetooth.info("Subscribed to color temperature notifications")
                    } catch {
                        Logger.bluetooth.warning("Color temperature notification subscription failed: \(error.localizedDescription)")
                    }
                }
            } catch {
                Logger.bluetooth.warning("Color temperature read failed: \(error.localizedDescription)")
            }
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
        if let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data],
           serviceData.keys.contains(hueAdvertisementUUID) {
            return true
        }
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
            case powerCharacteristicUUID:
                lastDiscoveredCharacteristics.power = characteristic
            case brightnessCharacteristicUUID:
                lastDiscoveredCharacteristics.brightness = characteristic
            case colorTemperatureCharacteristicUUID:
                lastDiscoveredCharacteristics.colorTemperature = characteristic
            default:
                break
            }
        }

        characteristicsContinuation?.resume()
        characteristicsContinuation = nil
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            readValueContinuation?.resume(throwing: error)
        } else {
            readValueContinuation?.resume()
        }
        readValueContinuation = nil
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            Logger.bluetooth.warning("Notify subscription failed for \(characteristic.uuid): \(error.localizedDescription)")
            notifyContinuation?.resume(throwing: error)
        } else {
            Logger.bluetooth.info("Notify subscription succeeded for \(characteristic.uuid), isNotifying=\(characteristic.isNotifying)")
            notifyContinuation?.resume()
        }
        notifyContinuation = nil
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            Logger.bluetooth.warning("Write failed for \(characteristic.uuid): \(error.localizedDescription)")
            writeValueContinuation?.resume(throwing: error)
        } else {
            Logger.bluetooth.info("Write succeeded for \(characteristic.uuid)")
            writeValueContinuation?.resume()
        }
        writeValueContinuation = nil
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
    case pairingRequired

    var errorDescription: String? {
        switch self {
        case .bluetoothNotAvailable: return "Bluetooth is not available or not authorized"
        case .noBulbsFound: return "No Hue Bluetooth bulbs found nearby. Make sure the bulb is powered on and within range."
        case .connectionTimeout: return "Connection to bulb timed out"
        case .connectionFailed: return "Failed to connect to bulb"
        case .discoveryTimeout: return "Service discovery timed out"
        case .serviceNotFound: return "Hue light control service not found on bulb"
        case .characteristicNotFound: return "Control characteristic not found"
        case .peripheralNotFound: return "Bulb not found"
        case .pairingRequired: return "Bulb requires pairing. Open the Hue app → Settings → Voice Assistants → Google Home → Make Discoverable, then reconnect."
        }
    }
}
