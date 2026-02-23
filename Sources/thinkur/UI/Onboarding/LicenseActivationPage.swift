import SwiftUI

struct LicenseActivationPage: View {
    @Environment(OnboardingViewModel.self) private var viewModel
    @Environment(LicenseManager.self) private var licenseManager
    @Environment(SettingsManager.self) private var settings

    @State private var licenseKey = ""
    @State private var isActivating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            VStack(spacing: Spacing.sm) {
                Text("Choose your plan")
                    .font(Typography.onboardingTitle)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text("Unlock thinkur, then enter your key to finish.")
                    .font(Typography.onboardingBody)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }

            // Plan cards
            HStack(spacing: Spacing.md) {
                PlanCard(
                    title: "Monthly",
                    price: "£5",
                    period: "/ month",
                    detail: "Cancel anytime",
                    action: "Subscribe"
                ) {
                    if let url = URL(string: Constants.checkoutURLMonthly) {
                        NSWorkspace.shared.open(url)
                    }
                }

                PlanCard(
                    title: "Lifetime",
                    price: "£28",
                    period: "one-time",
                    detail: "Pay once, use forever",
                    action: "Purchase",
                    highlighted: true
                ) {
                    if let url = URL(string: Constants.checkoutURLLifetime) {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            .frame(maxWidth: 460)

            // Activation section
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
                        .tint(settings.accentUITint)
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

            VStack(spacing: Spacing.xxs) {
                Text("Already purchased? Check [your account](\(Constants.customerPortalURL)) for your key.")
                Text("Need help? [jyo@thinkur.app](mailto:jyo@thinkur.app)")
            }
            .font(Typography.caption)
            .foregroundStyle(ColorTokens.textTertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 460)

            Spacer()

            Spacer()
                .frame(height: Spacing.xl)
        }
        .padding(.horizontal, Spacing.xl)
        .onAppear {
            if licenseManager.isLicensed {
                viewModel.nextStep()
            }
        }
        .onChange(of: licenseManager.isLicensed) { _, isLicensed in
            if isLicensed {
                viewModel.nextStep()
            }
        }
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

// MARK: - Plan Card

private struct PlanCard: View {
    @Environment(SettingsManager.self) private var settings
    let title: String
    let price: String
    let period: String
    let detail: String
    let action: String
    var highlighted: Bool = false
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            VStack(spacing: Spacing.xxs) {
                Text(title)
                    .font(Typography.headline)
                    .foregroundStyle(ColorTokens.textSecondary)

                HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                    Text(price)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(ColorTokens.textPrimary)

                    Text(period)
                        .font(Typography.callout)
                        .foregroundStyle(ColorTokens.textTertiary)
                }

                Text(detail)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            Button(action: onTap) {
                Text(action)
                    .font(Typography.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xs)
            }
            .buttonStyle(.glassProminent)
            .tint(settings.accentUITint)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .strokeBorder(
                    highlighted ? settings.accentUITint.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
    }
}
