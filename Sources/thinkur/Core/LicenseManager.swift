import Foundation
import IOKit
import os

@MainActor
@Observable
final class LicenseManager {
    private(set) var status: LicenseStatus = .unlicensed
    private(set) var planName: String?
    private(set) var activatedAt: Date?
    private(set) var expiresAt: Date?
    private(set) var maskedKey: String?

    var isLicensed: Bool { status == .active }

    private static let keychainAccountLicense = "license_data"
    private static let keychainAccountValidation = "last_validation"
    private static let gracePeriodDays: TimeInterval = 7 * 24 * 60 * 60

    private let logger = Logger(subsystem: "com.jyo.thinkur", category: "LicenseManager")
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
        loadCachedLicense()
    }

    // MARK: - Activate

    func activate(key: String) async throws -> Bool {
        status = .validating

        let body: [String: String] = [
            "license_key": key,
            "instance_name": machineID,
        ]

        var request = URLRequest(url: URL(string: "\(Constants.lemonSqueezyAPIBase)/v1/licenses/activate")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            status = .invalid
            return false
        }

        guard httpResponse.statusCode == 200 else {
            status = .invalid
            return false
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let activated = json["activated"] as? Bool, activated,
              let licenseKey = json["license_key"] as? [String: Any],
              let statusString = licenseKey["status"] as? String,
              statusString == "active" else {
            status = .invalid
            return false
        }

        cacheLicenseData(data)
        cacheValidationDate(Date())
        applyLicenseData(json)
        status = .active
        logger.info("License activated successfully")
        return true
    }

    // MARK: - Validate on Launch

    func validateOnLaunch() async {
        guard hasCachedLicense else {
            status = .unlicensed
            return
        }

        status = .validating

        guard let cachedData = KeychainHelper.load(account: Self.keychainAccountLicense),
              let cached = try? JSONSerialization.jsonObject(with: cachedData) as? [String: Any],
              let licenseKey = cached["license_key"] as? [String: Any],
              let key = licenseKey["key"] as? String else {
            status = .unlicensed
            return
        }

        let body: [String: String] = [
            "license_key": key,
            "instance_name": machineID,
        ]

        var request = URLRequest(url: URL(string: "\(Constants.lemonSqueezyAPIBase)/v1/licenses/validate")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let valid = json["valid"] as? Bool else {
                applyGracePeriodOrExpire()
                return
            }

            if valid {
                cacheLicenseData(data)
                cacheValidationDate(Date())
                applyLicenseData(json)
                status = .active
                logger.info("License validated on launch")
            } else {
                clearCachedLicense()
                status = .expired
                logger.info("License expired or invalid on validation")
            }
        } catch {
            applyGracePeriodOrExpire()
            logger.warning("License validation failed (offline?): \(error.localizedDescription)")
        }
    }

    // MARK: - Deactivate

    func deactivate() async {
        guard let cachedData = KeychainHelper.load(account: Self.keychainAccountLicense),
              let cached = try? JSONSerialization.jsonObject(with: cachedData) as? [String: Any],
              let licenseKey = cached["license_key"] as? [String: Any],
              let key = licenseKey["key"] as? String,
              let instanceData = cached["instance"] as? [String: Any],
              let instanceId = instanceData["id"] as? String else {
            clearCachedLicense()
            status = .unlicensed
            return
        }

        let body: [String: String] = [
            "license_key": key,
            "instance_id": instanceId,
        ]

        var request = URLRequest(url: URL(string: "\(Constants.lemonSqueezyAPIBase)/v1/licenses/deactivate")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        _ = try? await session.data(for: request)

        clearCachedLicense()
        status = .unlicensed
        planName = nil
        activatedAt = nil
        expiresAt = nil
        maskedKey = nil
        logger.info("License deactivated")
    }

    // MARK: - Machine ID

    private var machineID: String {
        let platformExpert = IOServiceGetMatchingService(
            kIOMasterPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        defer { IOObjectRelease(platformExpert) }

        guard platformExpert != 0,
              let serialNumber = IORegistryEntryCreateCFProperty(
                  platformExpert,
                  "IOPlatformUUID" as CFString,
                  kCFAllocatorDefault,
                  0
              )?.takeRetainedValue() as? String else {
            return ProcessInfo.processInfo.hostName
        }
        return serialNumber
    }

    // MARK: - Cache Helpers

    private var hasCachedLicense: Bool {
        KeychainHelper.load(account: Self.keychainAccountLicense) != nil
    }

    private func cacheLicenseData(_ data: Data) {
        _ = KeychainHelper.save(data, account: Self.keychainAccountLicense)
    }

    private func cacheValidationDate(_ date: Date) {
        let data = "\(date.timeIntervalSince1970)".data(using: .utf8)!
        _ = KeychainHelper.save(data, account: Self.keychainAccountValidation)
    }

    private func lastValidationDate() -> Date? {
        guard let data = KeychainHelper.load(account: Self.keychainAccountValidation),
              let string = String(data: data, encoding: .utf8),
              let interval = TimeInterval(string) else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    private func clearCachedLicense() {
        KeychainHelper.delete(account: Self.keychainAccountLicense)
        KeychainHelper.delete(account: Self.keychainAccountValidation)
    }

    private func loadCachedLicense() {
        guard let data = KeychainHelper.load(account: Self.keychainAccountLicense),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            status = .unlicensed
            return
        }
        applyLicenseData(json)
        // Don't set active yet — validateOnLaunch will confirm
        // But mark as validating so the paywall doesn't flash
        status = .validating
    }

    private func applyLicenseData(_ json: [String: Any]) {
        guard let licenseKey = json["license_key"] as? [String: Any] else { return }

        let rawName = licenseKey["variant_name"] as? String
            ?? (licenseKey["product_name"] as? String) ?? ""
        if rawName.localizedCaseInsensitiveContains("lifetime") {
            planName = "Lifetime"
        } else if rawName.localizedCaseInsensitiveContains("monthly") {
            planName = "Monthly"
        } else {
            // Fallback: if no expiry it's lifetime, otherwise monthly
            planName = (licenseKey["expires_at"] is NSNull || licenseKey["expires_at"] == nil)
                ? "Lifetime" : "Monthly"
        }

        if let key = licenseKey["key"] as? String, key.count > 8 {
            let suffix = String(key.suffix(4))
            maskedKey = "****-****-****-\(suffix)"
        }

        if let createdAt = licenseKey["created_at"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            activatedAt = formatter.date(from: createdAt)
        }

        if let expiresAtString = licenseKey["expires_at"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            expiresAt = formatter.date(from: expiresAtString)
        } else {
            expiresAt = nil // Lifetime license
        }
    }

    private func applyGracePeriodOrExpire() {
        if let lastValidation = lastValidationDate(),
           Date().timeIntervalSince(lastValidation) < Self.gracePeriodDays {
            status = .active
            logger.info("Offline grace period active")
        } else {
            status = .expired
            logger.info("Grace period expired — license locked")
        }
    }
}
