import SwiftUI

struct PaywallView: View {
    @Environment(LicenseManager.self) private var licenseManager
    @Environment(SharedAppState.self) private var sharedState
    @Environment(SettingsManager.self) private var settings
    @Environment(TelemetryService.self) private var telemetryService

    @State private var licenseKey = ""
    @State private var isActivating = false
    @State private var errorMessage: String?
    @State private var checkoutURL: URL?
    @State private var showCheckoutNudge = false
    @State private var reachedReceipt = false

    private var isExpiredLicense: Bool {
        licenseManager.status == .expired || licenseManager.status == .invalid
    }

    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                Spacer()

                // Header
                VStack(spacing: Spacing.sm) {
                    if isExpiredLicense {
                        Text("Your license has expired")
                            .font(Typography.onboardingTitle)
                            .foregroundStyle(ColorTokens.textPrimary)

                        Text("Reactivate to keep using thinkur.")
                            .font(Typography.onboardingBody)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 420)
                    } else {
                        Text("\(sharedState.freeWordsUsed.formatted()) words dictated, ~\(Formatters.formatTimeSaved(sharedState.freeTimeSaved)) saved")
                            .font(Typography.onboardingTitle)
                            .foregroundStyle(ColorTokens.textPrimary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 420)

                        Text("Get thinkur for life to keep going.")
                            .font(Typography.onboardingBody)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 420)
                    }
                }

                // Purchase button
                Button {
                    telemetryService.trackCheckoutOpened(planType: "lifetime", source: "paywall")
                    checkoutURL = URL(string: Constants.checkoutURLLifetime)
                } label: {
                    Text("Get Lifetime \u{00A3}28")
                        .font(Typography.headline)
                        .frame(maxWidth: 280)
                        .padding(.vertical, Spacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(settings.accentUITint)

                if showCheckoutNudge {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Purchase complete! Check your email for your license key.")
                            .font(Typography.callout)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .padding(Spacing.sm)
                    .frame(maxWidth: 420)
                    .interactiveCard()
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // License key activation
                GroupedSettingsSection(title: "Bought your key?") {
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
                .frame(maxWidth: 420)

                VStack(spacing: Spacing.xxs) {
                    Text((try? AttributedString(markdown: "Check [your orders](https://app.lemonsqueezy.com/my-orders) for your key.")) ?? AttributedString())
                    Text((try? AttributedString(markdown: "Student? Email [jyo@thinkur.app](mailto:jyo@thinkur.app) for a free key.")) ?? AttributedString())
                }
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

                Spacer()
            }
            .padding(.horizontal, Spacing.xl)
        }
        .frame(minWidth: 760, minHeight: 650)
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
