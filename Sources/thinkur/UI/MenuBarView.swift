import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var viewModel: MenuBarViewModel
    @EnvironmentObject var permissions: PermissionViewModel
    @EnvironmentObject var transcription: TranscriptionViewModel
    @EnvironmentObject var coordinator: AppCoordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.statusColor)
                    .frame(width: 8, height: 8)
                Text(viewModel.statusText)
                    .font(.headline)
                Spacer()
            }

            Divider()

            // Permission warnings
            if !permissions.allGranted {
                permissionWarnings
                Divider()
            }

            // Last transcription or instructions
            if transcription.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(transcription.loadingMessage.isEmpty ? "Loading..." : transcription.loadingMessage)
                        .foregroundStyle(.secondary)
                }
            } else if case .error = viewModel.appState {
                HStack(spacing: 8) {
                    Button("Retry") {
                        Task { await coordinator.retryModelLoad() }
                    }
                    .controlSize(.small)
                }
            } else if !viewModel.lastTranscription.isEmpty {
                Text(viewModel.lastTranscription)
                    .font(.body)
                    .lineLimit(4)
                    .textSelection(.enabled)
            } else if viewModel.appState == .idle {
                Text("Tap Tab to speak")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }

            // Frontmost app info
            if !viewModel.frontmostAppName.isEmpty {
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "app.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Text(viewModel.frontmostAppName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Button("Settings...") {
                openSettings()
            }
            .keyboardShortcut(",")

            Button("Quit thinkur") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 280)
    }

    private func openSettings() {
        openWindow(id: "settings")
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @ViewBuilder
    private var permissionWarnings: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !permissions.accessibilityGranted {
                PermissionRow(
                    label: "Accessibility",
                    action: { permissions.openAccessibilitySettings() }
                )
            }
            if !permissions.microphoneGranted {
                PermissionRow(
                    label: "Microphone",
                    action: { Task { await permissions.requestMicrophone() } }
                )
            }
            if !permissions.inputMonitoringGranted {
                PermissionRow(
                    label: "Input Monitoring",
                    action: { permissions.openInputMonitoringSettings() }
                )
            }
        }
    }
}

private struct PermissionRow: View {
    let label: String
    let action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .font(.caption)
            Text("\(label) needed")
                .font(.caption)
            Spacer()
            Button("Grant") { action() }
                .controlSize(.small)
        }
    }
}
