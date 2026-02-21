import CryptoKit
import Foundation
import os

/// URLSessionDelegate for Hue bridges on the LAN.
///
/// Security model:
/// - Only accepts TLS challenges for private/link-local hosts.
/// - Optionally constrains the challenge host to an expected bridge IP/host.
/// - Supports certificate pinning by SHA-256 of the leaf certificate (TOFU).
final class HueTrustDelegate: NSObject, URLSessionDelegate {
    private var expectedHost: String?
    private var pinnedCertificateSHA256: String?
    private(set) var observedCertificateSHA256: String?

    func configure(expectedHost: String?, pinnedCertificateSHA256: String?) {
        self.expectedHost = expectedHost?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.pinnedCertificateSHA256 = pinnedCertificateSHA256?.lowercased()
        self.observedCertificateSHA256 = nil
    }

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
        guard Self.isPrivateNetworkHost(host) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        if let expectedHost, !expectedHost.isEmpty,
           expectedHost.caseInsensitiveCompare(host) != .orderedSame {
            Logger.app.error("Hue TLS rejected unexpected host: \(host, privacy: .public)")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        guard let leafData = Self.leafCertificateData(from: serverTrust) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let fingerprint = Self.sha256Hex(of: leafData)
        if let pinnedCertificateSHA256 {
            guard fingerprint == pinnedCertificateSHA256 else {
                Logger.app.error("Hue TLS certificate pin mismatch for host \(host, privacy: .public)")
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }
        } else {
            // TOFU: capture the first seen cert hash so caller can persist it after successful pairing.
            observedCertificateSHA256 = fingerprint
        }

        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }

    /// Returns true if the host is in a private/link-local address range.
    static func isPrivateNetworkHost(_ host: String) -> Bool {
        let normalized = host
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            .lowercased()
        guard !normalized.isEmpty else { return false }

        if normalized.contains(":") {
            // IPv6 ULA (fc00::/7), link-local (fe80::/10), loopback (::1).
            return normalized == "::1"
                || normalized.hasPrefix("fc")
                || normalized.hasPrefix("fd")
                || normalized.hasPrefix("fe8")
                || normalized.hasPrefix("fe9")
                || normalized.hasPrefix("fea")
                || normalized.hasPrefix("feb")
        }

        let parts = normalized.split(separator: ".").compactMap { UInt8($0) }
        guard parts.count == 4 else { return false }
        switch parts[0] {
        case 10:
            return true // 10.0.0.0/8
        case 172:
            return (16...31).contains(parts[1]) // 172.16.0.0/12
        case 192:
            return parts[1] == 168 // 192.168.0.0/16
        case 169:
            return parts[1] == 254 // 169.254.0.0/16
        case 127:
            return true // loopback
        default:
            return false
        }
    }

    private static func leafCertificateData(from serverTrust: SecTrust) -> Data? {
        guard let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              let leaf = chain.first else {
            return nil
        }
        return SecCertificateCopyData(leaf) as Data
    }

    private static func sha256Hex(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
