import SwiftUI

struct PaywallView: View {
    @Environment(LicenseManager.self) private var licenseManager
    @Environment(SharedAppState.self) private var sharedState
    @Environment(TelemetryService.self) private var telemetryService

    @State private var licenseKey = ""
    @State private var isActivating = false
    @State private var errorMessage: String?
    @State private var checkoutURL: URL?
    @State private var showCheckoutNudge = false
    @State private var reachedReceipt = false

    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                Spacer()

                VStack(spacing: Spacing.sm) {
                    Text(licenseManager.status == .expired ? "Your subscription has expired" : "You\u{2019}ve used your free words")
                        .font(Typography.onboardingTitle)
                        .foregroundStyle(ColorTokens.textPrimary)

                    Text("Pick a plan to keep using thinkur.")
                        .font(Typography.onboardingBody)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 460)
                }

                HStack(spacing: Spacing.md) {
                    PlanCardCompact(
                        title: "Monthly",
                        price: "£5/mo",
                        action: "Subscribe"
                    ) {
                        telemetryService.trackCheckoutOpened(planType: "monthly", source: "paywall")
                        checkoutURL = URL(string: Constants.checkoutURLMonthly)
                    }

                    PlanCardCompact(
                        title: "Lifetime",
                        price: "£28",
                        action: "Purchase",
                        highlighted: true,
                        badge: "Best value"
                    ) {
                        telemetryService.trackCheckoutOpened(planType: "lifetime", source: "paywall")
                        checkoutURL = URL(string: Constants.checkoutURLLifetime)
                    }
                }
                .frame(maxWidth: 460)

                if showCheckoutNudge {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Purchase complete! Check your email for your license key.")
                            .font(Typography.callout)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .padding(Spacing.sm)
                    .frame(maxWidth: 460)
                    .interactiveCard()
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                GroupedSettingsSection(title: "Already have a key?") {
                    VStack(spacing: 0) {
                        HStack(spacing: Spacing.sm) {
                            TextField("XXXXX-XXXXX-XXXXX-XXXXX", text: $licenseKey)
                                .textFieldStyle(.plain)
                                .font(Typography.body)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.xs)
                                .materialClear(cornerRadius: CornerRadius.field)

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
                            .buttonStyle(.borderedProminent)
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

                VStack(spacing: Spacing.xxs) {
                    Text((try? AttributedString(markdown: "Already purchased? Check [your orders](https://app.lemonsqueezy.com/my-orders) for your key.")) ?? AttributedString())
                    Text((try? AttributedString(markdown: "Need help? [jyo@thinkur.app](mailto:jyo@thinkur.app)")) ?? AttributedString())
                }
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)

                Spacer()
            }
            .padding(.horizontal, Spacing.xl)
        }
        .frame(minWidth: 920, minHeight: 620)
        .sheet(isPresented: Binding(
            get: { checkoutURL != nil },
            set: { if !$0 { checkoutURL = nil } }
        ), onDismiss: {
            if reachedReceipt {
                withAnimation { showCheckoutNudge = true }
                reachedReceipt = false
            }
        }) {
            if let url = checkoutURL {
                CheckoutWebView(
                    url: url,
                    onLicenseKey: { key in
                        checkoutURL = nil
                        licenseKey = key
                        Task { await activateLicense() }
                    },
                    onDismiss: { checkoutURL = nil },
                    onReachedReceipt: { reachedReceipt = true }
                )
            }
        }
    }

    private func activateLicense() async {
        isActivating = true
        errorMessage = nil

        do {
            let success = try await licenseManager.activate(key: licenseKey.trimmingCharacters(in: .whitespaces))
            if success {
                sharedState.isUserLicensed = true
                sharedState.freeTierExhausted = false
            } else {
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
    var badge: String? = nil
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
            .buttonStyle(.borderedProminent)
            .tint(.primary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity)
        .interactiveCard()
        .overlay(alignment: .top) {
            if let badge {
                Text(badge)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 2)
                    .background(Color.accentColor, in: Capsule())
                    .offset(y: -10)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .strokeBorder(
                    highlighted ? ColorTokens.textPrimary.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
    }
}
