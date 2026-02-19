import SwiftUI

struct IntegrationsView: View {
    @Environment(IntegrationsViewModel.self) private var viewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("Connect smart home devices to control them with your voice.")
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textTertiary)

                // Philips Hue Section
                hueSection

                // Error display
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.danger)
                }

                // Discovered Lights
                if !viewModel.lights.isEmpty {
                    lightsSection
                }

                // Voice Commands
                if !viewModel.commands.isEmpty {
                    commandsSection
                }
            }
            .padding(Spacing.lg)
        }
    }

    // MARK: - Hue Section

    @ViewBuilder
    private var hueSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Philips Hue")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)
                .textCase(.uppercase)

            // Bridge card
            GroupedSettingsSection {
                VStack(spacing: 0) {
                    SettingsRowView(
                        icon: "lightbulb.led.wide",
                        title: "Hue Bridge",
                        subtitle: viewModel.isHueConnected ? "Connected" : "Control via your local network"
                    ) {
                        if viewModel.isHueConnected {
                            Button("Disconnect") {
                                viewModel.disconnectHue()
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(ColorTokens.danger)
                        } else {
                            Button("Connect") {
                                Task { await viewModel.connectHue() }
                            }
                            .disabled(viewModel.isConnectingHue)
                        }
                    }

                    // Pairing flow (inline in bridge card only)
                    if viewModel.isConnectingHue || viewModel.huePairingState != .idle && viewModel.huePairingState != .paired {
                        Divider()
                        HuePairingView(
                            pairingState: viewModel.huePairingState,
                            onConnect: { Task { await viewModel.connectHue() } },
                            onCancel: { viewModel.disconnectHue() }
                        )
                    }
                }
            }

            // Bluetooth card
            GroupedSettingsSection {
                SettingsRowView(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "Hue Bluetooth",
                    subtitle: hueBluetoothSubtitle
                ) {
                    if viewModel.isHueBluetoothConnected {
                        Button("Disconnect") {
                            viewModel.disconnectHueBluetooth()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(ColorTokens.danger)
                    } else {
                        if viewModel.isConnectingHueBluetooth {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Button("Connect") {
                                Task { await viewModel.connectHueBluetooth() }
                            }
                        }
                    }
                }
            }

            if !viewModel.isHueBluetoothConnected {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .padding(.top, 1)

                    Text("First time? Open the **Hue app** \u{2192} Settings \u{2192} Voice Assistants \u{2192} Google Home \u{2192} Make Discoverable. Then tap Connect — accept the macOS Bluetooth pairing dialog when it appears.")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .padding(.horizontal, Spacing.xs)
            }
        }
    }

    private var hueBluetoothSubtitle: String {
        if viewModel.isHueBluetoothConnected {
            return "Connected"
        } else if viewModel.isConnectingHueBluetooth {
            return "Scanning for bulbs..."
        } else {
            return "Direct to bulb, no bridge needed"
        }
    }

    // MARK: - Lights Section

    @ViewBuilder
    private var lightsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Discovered Lights")
                    .font(Typography.title3)
                    .foregroundStyle(ColorTokens.textPrimary)

                Spacer()

                if viewModel.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        Task { await viewModel.refreshLights() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(ColorTokens.textTertiary)
                }
            }

            ForEach(viewModel.lightsByRoom, id: \.room) { group in
                GroupedSettingsSection(title: group.room) {
                    VStack(spacing: 0) {
                        ForEach(group.lights) { light in
                            SmartLightRowView(
                                light: light,
                                onToggle: { on in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        viewModel.toggleLight(id: light.id, on: on)
                                    }
                                },
                                onBrightnessChange: { brightness in
                                    viewModel.setBrightness(id: light.id, brightness: brightness)
                                }
                            )
                            if light.id != group.lights.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Commands Section

    @ViewBuilder
    private var commandsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Voice Commands")
                .font(Typography.title3)
                .foregroundStyle(ColorTokens.textPrimary)

            Text("Say any of these while recording to control your lights.")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)

            GroupedSettingsSection {
                VStack(spacing: 0) {
                    ForEach(viewModel.commands.prefix(20)) { command in
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: commandIcon(command.action))
                                .font(.system(size: 12))
                                .foregroundStyle(ColorTokens.textTertiary)
                                .frame(width: 16)

                            Text(command.triggerPhrases.first ?? "")
                                .font(Typography.body)
                                .foregroundStyle(ColorTokens.textPrimary)

                            Spacer()

                            Text(command.targetName)
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 8)

                        if command.id != viewModel.commands.prefix(20).last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func commandIcon(_ action: SmartHomeAction) -> String {
        switch action {
        case .turnOn: return "power"
        case .turnOff: return "power"
        case .setBrightness: return "slider.horizontal.3"
        case .dim: return "sun.min"
        case .brighten: return "sun.max"
        case .fullBrightness: return "sun.max.fill"
        }
    }
}
