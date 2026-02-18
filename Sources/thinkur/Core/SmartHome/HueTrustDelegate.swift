import Foundation

/// URLSessionDelegate that trusts self-signed certificates from Hue bridges on the LAN.
/// Hue bridges use HTTPS with self-signed certs — we must accept them for local control.
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

        // Trust the bridge's self-signed certificate for local network communication
        let credential = URLCredential(trust: serverTrust)
        completionHandler(.useCredential, credential)
    }
}
