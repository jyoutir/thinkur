import SwiftUI

struct BillingView: View {
    @Environment(LicenseManager.self) private var licenseManager
    @Environment(SharedAppState.self) private var sharedState
    @Environment(SettingsManager.self) private var settings
    @State private var appeared = false
    @State private var licenseKey = ""
    @State private var isActivating = false
    @State private var errorMessage: String?
    @State private var checkoutURL: URL?
    @State private var showCheckoutNudge = false
    @State private var reachedReceipt = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("Manage your plan and license.")
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textTertiary)

                if sharedState.isFreeTier {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "text.word.spacing")
                            .font(.system(size: 13))
                            .foregroundStyle(ColorTokens.textSecondary)
                        Text("Free plan \u{2014} \(sharedState.freeWordsUsed.formatted()) / \(Constants.freeWordLimit.formatted()) words used")
                            .font(Typography.headline)
                            .foregroundStyle(ColorTokens.textPrimary)
                    }
                }

                if !sharedState.isFreeTier {
                    GroupedSettingsSection(title: "Current Plan") {
                        VStack(spacing: 0) {
                            SettingsRowView(icon: "crown.fill", title: "Plan") {
                                Text(licenseManager.planName ?? "thinkur")
                                    .font(Typography.caption)
                                    .foregroundStyle(Color(light: .white, dark: .black))
                                    .padding(.horizontal, Spacing.xs)
                                    .padding(.vertical, Spacing.xxs)
                                    .background(ColorTokens.textPrimary, in: Capsule())
                            }

                            Divider()

                            SettingsRowView(icon: "key.fill", title: "License Key") {
                                Text(licenseManager.maskedKey ?? "---")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(ColorTokens.textSecondary)
                            }

                            Divider()

                            SettingsRowView(icon: "checkmark.seal.fill", title: "Status") {
                                Text(statusLabel)
                                    .font(Typography.body)
                                    .foregroundStyle(statusColor)
                            }

                            if let activated = licenseManager.activatedAt {
                                Divider()

                                SettingsRowView(icon: "calendar", title: "Activated") {
                                    Text(activated, format: .dateTime.month(.wide).year())
                                        .font(Typography.body)
                                        .foregroundStyle(ColorTokens.textSecondary)
                                }
                            }

                            if let expires = licenseManager.expiresAt {
                                Divider()

                                SettingsRowView(icon: "clock", title: "Renews") {
                                    Text(expires, format: .dateTime.month(.abbreviated).day().year())
                                        .font(Typography.body)
                                        .foregroundStyle(ColorTokens.textSecondary)
                                }
                            }
                        }
                    }

                    Button("Manage Subscription") {
                        if let url = URL(string: Constants.customerPortalURL) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .controlSize(.regular)
                }

                if sharedState.isFreeTier, showCheckoutNudge {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Purchase complete! Check your email for your license key.")
                            .font(Typography.callout)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .padding(Spacing.sm)
                    .interactiveCard()
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if sharedState.isFreeTier {
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

                    Button {
                        checkoutURL = URL(string: Constants.checkoutURLLifetime)
                    } label: {
                        Text("Purchase Lifetime \u{2014} \u{00A3}28")
                            .font(Typography.headline)
                            .padding(.vertical, Spacing.xs)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
                }

                #if DEBUG
                Button("Reset to Onboarding (Debug)") {
                    Task {
                        await licenseManager.deactivate()
                        sharedState.isUserLicensed = false
                        sharedState.freeTierExhausted = false
                        settings.hasCompletedOnboarding = false
                    }
                }
                .foregroundStyle(.red)
                .controlSize(.regular)
                #endif
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.lg)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 6)
            .animation(Animations.glassMaterialize, value: appeared)
        }
        .navigationTitle("Billing")
        .onAppear { appeared = true }
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

    private var statusLabel: String {
        switch licenseManager.status {
        case .active: "Active"
        case .expired: "Expired"
        case .validating: "Validating..."
        case .invalid: "Invalid"
        case .unlicensed: "Unlicensed"
        }
    }

    private var statusColor: Color {
        switch licenseManager.status {
        case .active: .green
        case .expired, .invalid: .red
        default: ColorTokens.textSecondary
        }
    }
}
