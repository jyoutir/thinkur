import Foundation
import Security
import os

/// Direct Philips Hue Bridge API backend (CLIP v2)
@MainActor
final class HueBridgeBackend: SmartHomeBackend {
    let backendType: SmartHomeBackendType = .hue

    private(set) var isConnected = false
    private(set) var bridgeIP: String?
    private var apiKey: String?
    private var urlSession: URLSession?
    private let discovery = HueBridgeDiscovery()
    private let trustDelegate = HueTrustDelegate()

    /// Current pairing state for UI
    enum PairingState: Equatable {
        case idle
        case discovering
        case waitingForButton(bridgeIP: String)
        case paired
        case failed(String)
    }

    var pairingState: PairingState = .idle

    // MARK: - Keychain

    private static let keychainService = "com.jyo.thinkur.hue"
    private static let keychainAccountAPIKey = "hue-api-key"
    private static let keychainAccountBridgeIP = "hue-bridge-ip"
    private static let keychainAccountBridgeCertHash = "hue-bridge-cert-sha256"
    private static let requestTimeout: TimeInterval = 8
    private static let resourceTimeout: TimeInterval = 20

    @discardableResult
    private func saveToKeychain(account: String, value: String) -> Bool {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: account,
        ]
        deleteFromKeychain(account: account)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        addQuery[kSecUseDataProtectionKeychain as String] = true
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            Logger.app.error("Hue keychain write failed (\(status, privacy: .public))")
            return false
        }
        return true
    }

    private func loadFromKeychain(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseDataProtectionKeychain as String: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            Logger.app.error("Hue keychain read failed (\(status, privacy: .public))")
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func deleteFromKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            Logger.app.error("Hue keychain delete failed (\(status, privacy: .public))")
        }
    }

    private func makeSession(bridgeIP: String, pinnedCertificateSHA256: String?) -> URLSession {
        trustDelegate.configure(expectedHost: bridgeIP, pinnedCertificateSHA256: pinnedCertificateSHA256)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = Self.requestTimeout
        configuration.timeoutIntervalForResource = Self.resourceTimeout
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        return URLSession(configuration: configuration, delegate: trustDelegate, delegateQueue: nil)
    }

    private func persistObservedCertificateIfAvailable() {
        guard let observed = trustDelegate.observedCertificateSHA256, !observed.isEmpty else { return }
        _ = saveToKeychain(account: Self.keychainAccountBridgeCertHash, value: observed)
    }

    private func makeBridgeURL(ip: String, path: String) throws -> URL {
        guard HueTrustDelegate.isPrivateNetworkHost(ip) else {
            throw HueError.invalidBridgeHost
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = ip
        components.percentEncodedPath = path.hasPrefix("/") ? path : "/\(path)"
        guard let url = components.url else {
            throw HueError.invalidResponse
        }
        return url
    }

    // MARK: - SmartHomeBackend

    func connect() async throws {
        // Try to load saved credentials
        if let savedIP = loadFromKeychain(account: Self.keychainAccountBridgeIP),
           let savedKey = loadFromKeychain(account: Self.keychainAccountAPIKey) {
            guard HueTrustDelegate.isPrivateNetworkHost(savedIP) else {
                deleteFromKeychain(account: Self.keychainAccountAPIKey)
                deleteFromKeychain(account: Self.keychainAccountBridgeIP)
                deleteFromKeychain(account: Self.keychainAccountBridgeCertHash)
                throw HueError.invalidBridgeHost
            }

            let savedCertHash = loadFromKeychain(account: Self.keychainAccountBridgeCertHash)
            bridgeIP = savedIP
            apiKey = savedKey
            urlSession?.invalidateAndCancel()
            urlSession = makeSession(bridgeIP: savedIP, pinnedCertificateSHA256: savedCertHash)

            // Verify the connection still works
            do {
                _ = try await fetchLights()
                isConnected = true
                pairingState = .paired
                persistObservedCertificateIfAvailable()
                Logger.app.info("Reconnected to Hue bridge at \(savedIP)")
                return
            } catch {
                Logger.app.info("Saved Hue credentials invalid, re-pairing needed")
                deleteFromKeychain(account: Self.keychainAccountAPIKey)
                deleteFromKeychain(account: Self.keychainAccountBridgeIP)
                deleteFromKeychain(account: Self.keychainAccountBridgeCertHash)
            }
        }

        // Need to discover and pair
        try await discoverAndPair()
    }

    func disconnect() {
        deleteFromKeychain(account: Self.keychainAccountAPIKey)
        deleteFromKeychain(account: Self.keychainAccountBridgeIP)
        deleteFromKeychain(account: Self.keychainAccountBridgeCertHash)
        apiKey = nil
        bridgeIP = nil
        isConnected = false
        pairingState = .idle
        urlSession?.invalidateAndCancel()
        urlSession = nil
    }

    func discoverLights() async throws -> [SmartLight] {
        try await fetchLights()
    }

    func setLightState(id: String, state: LightStateChange) async throws {
        guard let session = urlSession, let ip = bridgeIP, let key = apiKey else {
            throw HueError.notConnected
        }

        let encodedID = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let url = try makeBridgeURL(ip: ip, path: "/clip/v2/resource/light/\(encodedID)")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue(key, forHTTPHeaderField: "hue-application-key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [:]
        if let on = state.on {
            body["on"] = ["on": on]
        }
        if let brightness = state.brightness {
            body["dimming"] = ["brightness": brightness]
        }
        if let colorTemp = state.colorTemperature {
            body["color_temperature"] = ["mirek": colorTemp]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw HueError.requestFailed
        }
    }

    // MARK: - Discovery & Pairing

    /// Full discovery + pairing flow. Call from UI.
    func discoverAndPair() async throws {
        pairingState = .discovering

        let bridges = try await discovery.discover()
        guard let bridge = bridges.first, !bridge.ip.isEmpty else {
            pairingState = .failed("No Hue Bridge found on your network")
            throw HueError.noBridgeFound
        }
        guard HueTrustDelegate.isPrivateNetworkHost(bridge.ip) else {
            pairingState = .failed("Bridge host is not on a private network")
            throw HueError.invalidBridgeHost
        }

        bridgeIP = bridge.ip
        urlSession?.invalidateAndCancel()
        urlSession = makeSession(bridgeIP: bridge.ip, pinnedCertificateSHA256: nil)
        pairingState = .waitingForButton(bridgeIP: bridge.ip)

        // Poll for link button press
        let key = try await pollForLinkButton(bridgeIP: bridge.ip)
        apiKey = key

        saveToKeychain(account: Self.keychainAccountAPIKey, value: key)
        saveToKeychain(account: Self.keychainAccountBridgeIP, value: bridge.ip)
        persistObservedCertificateIfAvailable()

        isConnected = true
        pairingState = .paired
        Logger.app.info("Paired with Hue bridge at \(bridge.ip)")
    }

    /// Poll the bridge until the user presses the link button (up to 30s)
    private func pollForLinkButton(bridgeIP: String) async throws -> String {
        guard let session = urlSession else { throw HueError.notConnected }
        let url = try makeBridgeURL(ip: bridgeIP, path: "/api")
        let bodyData = try JSONSerialization.data(withJSONObject: [
            "devicetype": "thinkur#macOS",
            "generateclientkey": true,
        ])

        for _ in 0..<15 {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = bodyData
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

            let (data, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                throw HueError.requestFailed
            }

            if let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let first = results.first {
                if let success = first["success"] as? [String: Any],
                   let username = success["username"] as? String {
                    return username
                }
                // error 101 = link button not pressed, keep polling
            }

            try await Task.sleep(for: .seconds(2))
        }

        pairingState = .failed("Timed out waiting for button press")
        throw HueError.linkButtonTimeout
    }

    // MARK: - API Calls

    private func fetchLights() async throws -> [SmartLight] {
        guard let session = urlSession, let ip = bridgeIP, let key = apiKey else {
            throw HueError.notConnected
        }

        let lightsURL = try makeBridgeURL(ip: ip, path: "/clip/v2/resource/light")
        var lightsRequest = URLRequest(url: lightsURL)
        lightsRequest.addValue(key, forHTTPHeaderField: "hue-application-key")

        let (lightsData, lightsResponse) = try await session.data(for: lightsRequest)
        guard let httpResponse = lightsResponse as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw HueError.requestFailed
        }

        // Fetch rooms for room names
        let roomMap = try await fetchRoomMap()

        // Parse CLIP v2 response
        guard let json = try JSONSerialization.jsonObject(with: lightsData) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]] else {
            throw HueError.invalidResponse
        }

        var lights: [SmartLight] = []
        for item in dataArray {
            guard let id = item["id"] as? String,
                  let metadata = item["metadata"] as? [String: Any],
                  let name = metadata["name"] as? String else {
                continue
            }

            let isOn: Bool
            if let onState = item["on"] as? [String: Any], let on = onState["on"] as? Bool {
                isOn = on
            } else {
                isOn = false
            }

            let brightness: Int
            if let dimming = item["dimming"] as? [String: Any], let bri = dimming["brightness"] as? Double {
                brightness = Int(bri)
            } else {
                brightness = 0
            }

            let colorTemperature: Int?
            if let ct = item["color_temperature"] as? [String: Any], let mirek = ct["mirek"] as? Int {
                colorTemperature = mirek
            } else {
                colorTemperature = nil
            }

            // Find room by checking which room contains this light's owner
            let owner = item["owner"] as? [String: Any]
            let ownerRid = owner?["rid"] as? String
            let roomName = ownerRid.flatMap { roomMap[$0] }

            lights.append(SmartLight(
                id: id,
                name: name,
                roomName: roomName,
                isOn: isOn,
                brightness: brightness,
                colorTemperature: colorTemperature,
                isReachable: true,
                backend: .hue
            ))
        }

        return lights
    }

    /// Fetch room-to-name mapping. Returns [deviceRid: roomName]
    private func fetchRoomMap() async throws -> [String: String] {
        guard let session = urlSession, let ip = bridgeIP, let key = apiKey else {
            return [:]
        }

        let url = try makeBridgeURL(ip: ip, path: "/clip/v2/resource/room")
        var request = URLRequest(url: url)
        request.addValue(key, forHTTPHeaderField: "hue-application-key")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return [:]
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rooms = json["data"] as? [[String: Any]] else {
            return [:]
        }

        var map: [String: String] = [:]
        for room in rooms {
            guard let metadata = room["metadata"] as? [String: Any],
                  let roomName = metadata["name"] as? String,
                  let children = room["children"] as? [[String: Any]] else {
                continue
            }
            for child in children {
                if let rid = child["rid"] as? String {
                    map[rid] = roomName
                }
            }
        }

        return map
    }

    // MARK: - Room-Level Control

    /// Set state for all lights in a room
    func setRoomLightsState(roomName: String, state: LightStateChange, lights: [SmartLight]) async throws {
        let roomLights = lights.filter { $0.roomName == roomName && $0.backend == .hue }
        for light in roomLights {
            try await setLightState(id: light.id, state: state)
        }
    }
}

// MARK: - Errors

enum HueError: LocalizedError {
    case noBridgeFound
    case linkButtonTimeout
    case notConnected
    case invalidBridgeHost
    case requestFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noBridgeFound: return "No Hue Bridge found on your network"
        case .linkButtonTimeout: return "Timed out waiting for bridge button press"
        case .notConnected: return "Not connected to Hue Bridge"
        case .invalidBridgeHost: return "Hue bridge host is invalid or not private"
        case .requestFailed: return "Bridge request failed"
        case .invalidResponse: return "Invalid response from bridge"
        }
    }
}
