import SwiftUI

struct BillingView: View {
    @Environment(LicenseManager.self) private var licenseManager
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
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

                #if DEBUG
                Button("Reset License (Debug)") {
                    Task { await licenseManager.deactivate() }
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
