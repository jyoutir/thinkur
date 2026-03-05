import SwiftUI

struct PricingPage: View {
    @Environment(OnboardingViewModel.self) private var viewModel
    @Environment(LicenseManager.self) private var licenseManager
    @Environment(SharedAppState.self) private var sharedState
    @Environment(SettingsManager.self) private var settings

    @State private var licenseKey = ""
    @State private var isActivating = false
    @State private var errorMessage: String?
    @State private var checkoutURL: URL?
    @State private var showCheckoutNudge = false
    @State private var reachedReceipt = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            VStack(spacing: Spacing.sm) {
                Text("Choose your plan")
                    .font(Typography.onboardingTitle)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text("Your first 5,000 words are free. No credit card needed.")
                    .font(Typography.onboardingBody)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }

            HStack(spacing: Spacing.md) {
                // Free plan
                VStack(spacing: Spacing.sm) {
                    VStack(spacing: Spacing.xxs) {
                        Text("Free")
                            .font(Typography.headline)
                            .foregroundStyle(ColorTokens.textSecondary)
                        Text("\u{00A3}0")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(ColorTokens.textPrimary)
                        Text("5,000 words free")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }

                    Button {
                        viewModel.nextStep()
                    } label: {
                        Text("Start free")
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

                // Lifetime plan
                VStack(spacing: Spacing.sm) {
                    VStack(spacing: Spacing.xxs) {
                        Text("Lifetime")
                            .font(Typography.headline)
                            .foregroundStyle(ColorTokens.textSecondary)
                        Text("\u{00A3}28")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(ColorTokens.textPrimary)
                        Text("Use forever")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }

                    Button {
                        checkoutURL = URL(string: Constants.checkoutURLLifetime)
                    } label: {
                        Text("Purchase")
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
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.card)
                        .strokeBorder(ColorTokens.textPrimary.opacity(0.3), lineWidth: 1)
                )
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

            Spacer()
        }
        .padding(.horizontal, Spacing.xl)
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
                viewModel.nextStep()
            } else {
                errorMessage = "Invalid license key. Please check and try again."
            }
        } catch {
            errorMessage = "Could not reach the license server. Check your connection."
        }

        isActivating = false
    }
}
