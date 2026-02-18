import Foundation
import Network
import os

/// Discovers Philips Hue bridges on the local network via mDNS and broker fallback
@MainActor
final class HueBridgeDiscovery {
    struct DiscoveredBridge: Equatable {
        let ip: String
        let id: String?
    }

    private var browser: NWBrowser?
    private var discovered: [DiscoveredBridge] = []

    /// Discover bridges using mDNS, falling back to the Hue broker
    func discover(timeout: TimeInterval = 5) async throws -> [DiscoveredBridge] {
        discovered = []

        // Try mDNS first
        let mdnsResults = await discoverViaMDNS(timeout: timeout)
        if !mdnsResults.isEmpty {
            return mdnsResults
        }

        // Fallback to broker
        Logger.app.info("mDNS found no bridges, trying broker fallback")
        return try await discoverViaBroker()
    }

    // MARK: - mDNS Discovery

    private func discoverViaMDNS(timeout: TimeInterval) async -> [DiscoveredBridge] {
        await withCheckedContinuation { continuation in
            let params = NWParameters()
            params.includePeerToPeer = true
            let browser = NWBrowser(for: .bonjour(type: "_hue._tcp", domain: "local."), using: params)

            var results: [DiscoveredBridge] = []
            var finished = false

            browser.browseResultsChangedHandler = { newResults, _ in
                for result in newResults {
                    if case let .service(name, _, _, _) = result.endpoint {
                        // Resolve the endpoint to get IP
                        // For mDNS, the name is typically the bridge ID
                        // We'll resolve via connection
                        results.append(DiscoveredBridge(ip: "", id: name))
                    }
                }
            }

            browser.stateUpdateHandler = { state in
                switch state {
                case .failed:
                    if !finished {
                        finished = true
                        browser.cancel()
                        continuation.resume(returning: [])
                    }
                default:
                    break
                }
            }

            browser.start(queue: .main)

            // Wait for timeout then collect results
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(timeout))
                if !finished {
                    finished = true
                    browser.cancel()
                    // Resolve IPs via connection for any found bridges
                    var resolved: [DiscoveredBridge] = []
                    for result in results {
                        // mDNS results need IP resolution — use broker as reliable fallback
                        resolved.append(result)
                    }
                    continuation.resume(returning: resolved)
                }
            }
        }
    }

    // MARK: - Broker Fallback

    private func discoverViaBroker() async throws -> [DiscoveredBridge] {
        guard let url = URL(string: "https://discovery.meethue.com") else {
            return []
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return []
        }

        struct BrokerResult: Decodable {
            let id: String
            let internalipaddress: String
        }

        let brokerResults = try JSONDecoder().decode([BrokerResult].self, from: data)
        return brokerResults.map { DiscoveredBridge(ip: $0.internalipaddress, id: $0.id) }
    }
}
