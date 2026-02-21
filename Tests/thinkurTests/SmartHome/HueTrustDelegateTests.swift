import Testing
@testable import thinkur

@Suite("HueTrustDelegate")
struct HueTrustDelegateTests {
    @Test("Accepts private and link-local IPv4 hosts")
    func acceptsPrivateIPv4Hosts() {
        #expect(HueTrustDelegate.isPrivateNetworkHost("10.1.2.3"))
        #expect(HueTrustDelegate.isPrivateNetworkHost("172.16.0.10"))
        #expect(HueTrustDelegate.isPrivateNetworkHost("192.168.1.1"))
        #expect(HueTrustDelegate.isPrivateNetworkHost("169.254.22.4"))
    }

    @Test("Rejects public IPv4 and non-IP hosts")
    func rejectsPublicOrNonIPHosts() {
        #expect(!HueTrustDelegate.isPrivateNetworkHost("8.8.8.8"))
        #expect(!HueTrustDelegate.isPrivateNetworkHost("203.0.113.50"))
        #expect(!HueTrustDelegate.isPrivateNetworkHost("example.com"))
        #expect(!HueTrustDelegate.isPrivateNetworkHost("bridge.local"))
    }

    @Test("Accepts private IPv6 ranges")
    func acceptsPrivateIPv6Hosts() {
        #expect(HueTrustDelegate.isPrivateNetworkHost("fd12:3456:789a::1"))
        #expect(HueTrustDelegate.isPrivateNetworkHost("fe80::1"))
        #expect(HueTrustDelegate.isPrivateNetworkHost("[fe80::abcd]"))
    }

    @Test("Rejects public IPv6 ranges")
    func rejectsPublicIPv6Hosts() {
        #expect(!HueTrustDelegate.isPrivateNetworkHost("2001:4860:4860::8888"))
        #expect(!HueTrustDelegate.isPrivateNetworkHost("2606:4700:4700::1111"))
    }
}
