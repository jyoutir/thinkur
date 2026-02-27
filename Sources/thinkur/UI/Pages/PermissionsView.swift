import SwiftUI

struct PermissionsView: View {
    @Environment(PermissionManager.self) private var viewModel
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("thinkur needs these permissions to work properly.")
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textTertiary)

                GroupedSettingsSection {
                    VStack(spacing: 0) {
                        PermissionRowView(
                            icon: "mic.fill",
                            name: "Microphone",
                            description: "Required to capture your voice for transcription",
                            isGranted: viewModel.microphoneGranted,
                            helpText: "Audio input for on-device speech processing.",
                            action: { Task { await viewModel.requestMicrophone() } }
                        )

                        Divider()

                        PermissionRowView(
                            icon: "hand.raised.fill",
                            name: "Accessibility",
                            description: "Required to insert text into other applications",
                            isGranted: viewModel.accessibilityGranted,
                            helpText: "Injects transcribed text into the active app.",
                            action: { viewModel.requestAccessibility() }
                        )

                        Divider()

                        PermissionRowView(
                            icon: "keyboard.fill",
                            name: "Input Monitoring",
                            description: "Required to detect the hotkey for activating voice typing",
                            isGranted: viewModel.inputMonitoringGranted,
                            helpText: "Detects your hotkey to activate listening mode.",
                            action: {
                                viewModel.requestInputMonitoring()
                                viewModel.openInputMonitoringSettings()
                            }
                        )
                    }
                }

                Button("Open System Settings") {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!
                    )
                }
                .controlSize(.regular)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.lg)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 6)
            .animation(Animations.glassMaterialize, value: appeared)
        }
        .navigationTitle("Permissions")
        .task {
            viewModel.checkAll()
        }
        .onAppear { appeared = true }
    }
}
