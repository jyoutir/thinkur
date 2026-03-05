import SwiftUI

struct BillingView: View {
    @Environment(LicenseManager.self) private var licenseManager
    @Environment(SharedAppState.self) private var sharedState
    @Environment(SettingsManager.self) private var settings
    @Environment(TelemetryService.self) private var telemetryService
    @State private var appeared = false
    @State private var checkoutURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                if sharedState.isFreeTier {
                    // Free tier: show usage + upgrade
                    Text("You\u{2019}re on the free plan.")
                        .font(Typography.callout)
                        .foregroundStyle(ColorTokens.textTertiary)

                    GroupedSettingsSection(title: "Usage") {
                        VStack(spacing: Spacing.sm) {
                            HStack {
                                Text("\(sharedState.freeWordsUsed.formatted()) / \(Constants.freeWordLimit.formatted()) words")
                                    .font(Typography.headline)
                                    .foregroundStyle(ColorTokens.textPrimary)
                                Spacer()
                                Text("\(sharedState.freeWordsRemaining.formatted()) left")
                                    .font(Typography.caption)
                                    .foregroundStyle(sharedState.freeWordsRemaining < 500 ? .orange : ColorTokens.textSecondary)
                            }

                            // Progress bar
                            Capsule()
                                .fill(ColorTokens.border)
                                .frame(height: 6)
                                .overlay(alignment: .leading) {
                                    GeometryReader { geo in
                                        Capsule()
                                            .fill(sharedState.freeWordsRemaining < 500 ? Color.orange : settings.accentUITint)
                                            .frame(width: max(geo.size.width * Double(sharedState.freeWordsUsed) / Double(Constants.freeWordLimit), 6), height: 6)
                                    }
                                }
                                .clipShape(Capsule())
                        }
                        .padding(Spacing.md)
                    }

                    // Upgrade cards
                    HStack(spacing: Spacing.md) {
                        PlanCardSmall(title: "Monthly", price: "\u{00A3}5/mo", action: "Subscribe") {
                            telemetryService.trackCheckoutOpened(planType: "monthly", source: "billing")
                            checkoutURL = URL(string: Constants.checkoutURLMonthly)
                        }
                        PlanCardSmall(title: "Lifetime", price: "\u{00A3}28", action: "Purchase", highlighted: true) {
                            telemetryService.trackCheckoutOpened(planType: "lifetime", source: "billing")
                            checkoutURL = URL(string: Constants.checkoutURLLifetime)
                        }
                    }
                } else {
                    // Licensed user: existing plan management
                    Text("Manage your subscription and payment details.")
                        .font(Typography.callout)
                        .foregroundStyle(ColorTokens.textTertiary)

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

                #if DEBUG
                Button("Reset to Onboarding (Debug)") {
                    Task {
                        await licenseManager.deactivate()
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
        )) {
            if let url = checkoutURL {
                CheckoutWebView(
                    url: url,
                    onLicenseKey: { key in
                        checkoutURL = nil
                        Task {
                            let success = try? await licenseManager.activate(key: key)
                            if success == true {
                                sharedState.isUserLicensed = true
                                sharedState.freeTierExhausted = false
                            }
                        }
                    },
                    onDismiss: { checkoutURL = nil },
                    onReachedReceipt: { }
                )
            }
        }
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

// MARK: - Small Plan Card (Billing)

private struct PlanCardSmall: View {
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
            .buttonStyle(.borderedProminent)
            .tint(.primary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity)
        .interactiveCard()
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .strokeBorder(
                    highlighted ? ColorTokens.textPrimary.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
    }
}
