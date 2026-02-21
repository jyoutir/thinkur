import SwiftUI

struct PaywallView: View {
    @Environment(LicenseManager.self) private var licenseManager

    @State private var licenseKey = ""
    @State private var isActivating = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                Spacer()

                VStack(spacing: Spacing.sm) {
                    Text("Your license has expired")
                        .font(Typography.onboardingTitle)
                        .foregroundStyle(ColorTokens.textPrimary)

                    Text("Renew your subscription or enter a new license key to continue using thinkur.")
                        .font(Typography.onboardingBody)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 460)
                }

                HStack(spacing: Spacing.md) {
                    PlanCardCompact(
                        title: "Monthly",
                        price: "$5/mo",
                        action: "Subscribe"
                    ) {
                        if let url = URL(string: Constants.checkoutURLMonthly) {
                            NSWorkspace.shared.open(url)
                        }
                    }

                    PlanCardCompact(
                        title: "Lifetime",
                        price: "$29",
                        action: "Purchase",
                        highlighted: true
                    ) {
                        if let url = URL(string: Constants.checkoutURLLifetime) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                .frame(maxWidth: 460)

                GroupedSettingsSection(title: "Already have a key?") {
                    VStack(spacing: 0) {
                        HStack(spacing: Spacing.sm) {
                            TextField("XXXXX-XXXXX-XXXXX-XXXXX", text: $licenseKey)
                                .textFieldStyle(.plain)
                                .font(Typography.body)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.xs)
                                .glassClear(cornerRadius: CornerRadius.field)

                            Button {
                                Task { await activateLicense() }
                            } label: {
                                HStack(spacing: Spacing.xxs) {
                                    if isActivating {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                    Text("Activate")
                                        .font(Typography.headline)
                                }
                                .padding(.horizontal, Spacing.md)
                                .padding(.vertical, Spacing.xs)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(.primary)
                            .disabled(licenseKey.trimmingCharacters(in: .whitespaces).isEmpty || isActivating)
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)

                        if let error = errorMessage {
                            HStack(spacing: Spacing.xxs) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11))
                                Text(error)
                                    .font(Typography.caption)
                            }
                            .foregroundStyle(.red)
                            .padding(.horizontal, Spacing.md)
                            .padding(.bottom, Spacing.sm)
                        }
                    }
                }
                .frame(maxWidth: 460)

                Spacer()
            }
            .padding(.horizontal, Spacing.xl)
        }
        .frame(minWidth: 920, minHeight: 620)
    }

    private func activateLicense() async {
        isActivating = true
        errorMessage = nil

        do {
            let success = try await licenseManager.activate(key: licenseKey.trimmingCharacters(in: .whitespaces))
            if !success {
                errorMessage = "Invalid license key. Please check and try again."
            }
        } catch {
            errorMessage = "Could not reach the license server. Check your connection."
        }

        isActivating = false
    }
}

// MARK: - Compact Plan Card

private struct PlanCardCompact: View {
    let title: String
    let price: String
    let action: String
    var highlighted: Bool = false
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: Spacing.sm) {
            VStack(spacing: Spacing.xxs) {
                Text(title)
                    .font(Typography.headline)
                    .foregroundStyle(ColorTokens.textSecondary)

                Text(price)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(ColorTokens.textPrimary)
            }

            Button(action: onTap) {
                Text(action)
                    .font(Typography.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xs)
            }
            .buttonStyle(.glassProminent)
            .tint(.primary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .strokeBorder(
                    highlighted ? ColorTokens.textPrimary.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
    }
}
