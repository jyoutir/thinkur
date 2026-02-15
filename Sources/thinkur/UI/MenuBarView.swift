import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppStateManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(appState.statusColor)
                    .frame(width: 8, height: 8)
                Text(appState.statusText)
                    .font(.headline)
                Spacer()
            }

            Divider()

            // Permission warnings
            if !appState.permissionManager.allGranted {
                permissionWarnings
                Divider()
            }

            // Last transcription or instructions
            if appState.transcriptionEngine.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading model...")
                        .foregroundStyle(.secondary)
                }
            } else if !appState.lastTranscription.isEmpty {
                Text(appState.lastTranscription)
                    .font(.body)
                    .lineLimit(4)
                    .textSelection(.enabled)
            } else if appState.state == .idle {
                Text("Tap Tab to speak")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }

            // Frontmost app info
            if !appState.frontmostAppDetector.appName.isEmpty {
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "app.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Text(appState.frontmostAppDetector.appName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Button("Quit thinkur") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 280)
    }

    @ViewBuilder
    private var permissionWarnings: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !appState.permissionManager.accessibilityGranted {
                PermissionRow(
                    label: "Accessibility",
                    action: { appState.permissionManager.openAccessibilitySettings() }
                )
            }
            if !appState.permissionManager.microphoneGranted {
                PermissionRow(
                    label: "Microphone",
                    action: { Task { await appState.permissionManager.requestMicrophone() } }
                )
            }
            if !appState.permissionManager.inputMonitoringGranted {
                PermissionRow(
                    label: "Input Monitoring",
                    action: { appState.permissionManager.openInputMonitoringSettings() }
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
