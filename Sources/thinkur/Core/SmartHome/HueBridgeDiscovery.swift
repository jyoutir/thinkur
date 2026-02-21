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

    /// Discover bridges using mDNS, falling back to the Hue broker
    func discover(timeout: TimeInterval = 5) async throws -> [DiscoveredBridge] {
        // Try mDNS first
        let mdnsResults = await discoverViaMDNS(timeout: timeout)
        let validMDNSResults = mdnsResults.filter { !$0.ip.isEmpty && HueTrustDelegate.isPrivateNetworkHost($0.ip) }
        if !validMDNSResults.isEmpty {
            return validMDNSResults
        }

        // Fallback to broker
        Logger.app.info("mDNS found no bridges, trying broker fallback")
        return try await discoverViaBroker()
    }

    // MARK: - mDNS Discovery

    private func discoverViaMDNS(timeout: TimeInterval) async -> [DiscoveredBridge] {
        final class DiscoveryAccumulator {
            var results: [DiscoveredBridge] = []
            var finished = false
        }

        return await withCheckedContinuation { continuation in
            let params = NWParameters()
            params.includePeerToPeer = true
            let browser = NWBrowser(for: .bonjour(type: "_hue._tcp", domain: "local."), using: params)

            let accumulator = DiscoveryAccumulator()

            browser.browseResultsChangedHandler = { newResults, _ in
                for result in newResults {
                    if case let .service(name, _, _, _) = result.endpoint {
                        if !accumulator.results.contains(where: { $0.id == name }) {
                            // NWBrowser service results do not include direct IPs; keep ID only.
                            accumulator.results.append(DiscoveredBridge(ip: "", id: name))
                        }
                    }
                }
            }

            browser.stateUpdateHandler = { state in
                switch state {
                case .failed:
                    if !accumulator.finished {
                        accumulator.finished = true
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
                if !accumulator.finished {
                    accumulator.finished = true
                    browser.cancel()
                    continuation.resume(returning: accumulator.results)
                }
            }
        }
    }

    // MARK: - Broker Fallback

    private func discoverViaBroker() async throws -> [DiscoveredBridge] {
        guard let url = URL(string: "https://discovery.meethue.com") else {
            return []
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 6
        configuration.timeoutIntervalForResource = 10
        let session = URLSession(configuration: configuration)
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return []
        }

        struct BrokerResult: Decodable {
            let id: String
            let internalipaddress: String
        }

        let brokerResults = try JSONDecoder().decode([BrokerResult].self, from: data)
        return brokerResults
            .map { DiscoveredBridge(ip: $0.internalipaddress, id: $0.id) }
            .filter { HueTrustDelegate.isPrivateNetworkHost($0.ip) }
    }
}
