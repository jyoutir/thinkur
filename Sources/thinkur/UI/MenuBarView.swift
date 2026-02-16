import SwiftUI

struct MenuBarView: View {
    @Environment(MenuBarViewModel.self) private var viewModel
    @Environment(PermissionManager.self) private var permissions
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Status indicator
            HStack(spacing: 8) {
                statusDot
                Text(viewModel.statusText)
                    .font(Typography.headline)
                Spacer()
            }

            Divider()

            // Permission warnings
            if !permissions.allGranted {
                permissionWarnings
                Divider()
            }

            // Last transcription or instructions
            if viewModel.isModelLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(viewModel.modelLoadingMessage.isEmpty ? "Loading..." : viewModel.modelLoadingMessage)
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.currentAppState == .processing {
                HStack(spacing: 8) {
                    ThinkingDotsView(dotSize: 5, color: .secondary, spacing: 3)
                    Text("Thinking...")
                        .font(Typography.body)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            } else if case .error = viewModel.currentAppState {
                HStack(spacing: 8) {
                    Button("Retry") {
                        Task { await coordinator.retryModelLoad() }
                    }
                    .controlSize(.small)
                }
            } else if !viewModel.currentTranscription.isEmpty {
                Text(viewModel.currentTranscription)
                    .font(Typography.body)
                    .lineLimit(4)
                    .textSelection(.enabled)
                    .transition(.opacity)
            } else if viewModel.currentAppState == .idle {
                Text("Tap Tab to speak")
                    .foregroundStyle(.secondary)
                    .font(Typography.callout)
            }

            // Frontmost app info
            if !viewModel.frontmostAppName.isEmpty {
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "app.fill")
                        .foregroundStyle(.secondary)
                        .font(Typography.caption)
                    Text(viewModel.frontmostAppName)
                        .font(Typography.caption)
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
        .animation(Animations.hoverFade, value: viewModel.currentAppState)
    }

    @ViewBuilder
    private var statusDot: some View {
        Circle()
            .fill(viewModel.statusColor)
            .frame(width: 8, height: 8)
            .scaleEffect(viewModel.currentAppState == .listening ? 1.3 : 1.0)
            .animation(
                viewModel.currentAppState == .listening
                    ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                    : .default,
                value: viewModel.currentAppState
            )
    }

    private func openSettings() {
        openWindow(id: "main")
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @ViewBuilder
    private var permissionWarnings: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !permissions.accessibilityGranted {
                MenuBarPermissionRow(
                    label: "Accessibility",
                    action: { permissions.openAccessibilitySettings() }
                )
            }
            if !permissions.microphoneGranted {
                MenuBarPermissionRow(
                    label: "Microphone",
                    action: { Task { await permissions.requestMicrophone() } }
                )
            }
            if !permissions.inputMonitoringGranted {
                MenuBarPermissionRow(
                    label: "Input Monitoring",
                    action: { permissions.openInputMonitoringSettings() }
                )
            }
        }
    }
}

private struct MenuBarPermissionRow: View {
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
