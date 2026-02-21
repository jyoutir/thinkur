import Foundation

/// URLSessionDelegate that trusts self-signed certificates from Hue bridges on the LAN.
/// Hue bridges use HTTPS with self-signed certs — we must accept them for local control.
/// Only accepts challenges from private/link-local IP ranges to prevent MITM from public hosts.
final class HueTrustDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host
        guard Self.isPrivateNetwork(host) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Trust the bridge's self-signed certificate for local network communication
        let credential = URLCredential(trust: serverTrust)
        completionHandler(.useCredential, credential)
    }

    /// Returns true if the host is a private/link-local IP (RFC 1918 + RFC 3927).
    private static func isPrivateNetwork(_ host: String) -> Bool {
        let parts = host.split(separator: ".").compactMap { UInt8($0) }
        guard parts.count == 4 else { return false }
        switch parts[0] {
        case 10: return true                                       // 10.0.0.0/8
        case 172: return (16...31).contains(parts[1])              // 172.16.0.0/12
        case 192: return parts[1] == 168                           // 192.168.0.0/16
        case 169: return parts[1] == 254                           // 169.254.0.0/16 (link-local)
        default: return false
        }
    }
}
