import SwiftUI

struct PermissionsView: View {
    @Environment(PermissionManager.self) private var viewModel

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
                            iconColor: ColorTokens.accentRed,
                            name: "Microphone",
                            description: "Required to capture your voice for transcription",
                            isGranted: viewModel.microphoneGranted,
                            action: { Task { await viewModel.requestMicrophone() } }
                        )

                        Divider()

                        PermissionRowView(
                            icon: "hand.raised.fill",
                            iconColor: ColorTokens.accentBlue,
                            name: "Accessibility",
                            description: "Required to insert text into other applications",
                            isGranted: viewModel.accessibilityGranted,
                            action: { viewModel.openAccessibilitySettings() }
                        )

                        Divider()

                        PermissionRowView(
                            icon: "keyboard.fill",
                            iconColor: ColorTokens.accentPurple,
                            name: "Input Monitoring",
                            description: "Required to detect the hotkey for activating voice typing",
                            isGranted: viewModel.inputMonitoringGranted,
                            action: { viewModel.openInputMonitoringSettings() }
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
        }
        .navigationTitle("Permissions")
        .task {
            viewModel.checkAll()
        }
    }
}
