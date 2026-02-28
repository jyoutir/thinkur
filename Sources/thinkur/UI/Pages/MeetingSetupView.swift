import SwiftUI

struct MeetingSetupView: View {
    @Environment(PermissionManager.self) private var permissionManager
    @Environment(SettingsManager.self) private var settings
    @State private var pollingTimer: Timer?
    @State private var appeared = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            Image(systemName: "person.2.wave.2")
                .font(.system(size: 48))
                .foregroundStyle(settings.accentUITint.opacity(0.3))

            VStack(spacing: Spacing.sm) {
                Text("Set up Meetings")
                    .font(Typography.title)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text("Grant Screen Recording permission to capture audio from video calls, browser tabs, and other apps.")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            GroupedSettingsSection {
                PermissionRowView(
                    icon: "tv.and.mediabox",
                    name: "Screen Recording",
                    description: "Required to capture system audio during meetings",
                    isGranted: permissionManager.screenRecordingGranted,
                    helpText: "System Settings \u{2192} Privacy & Security \u{2192} Screen & System Audio Recording \u{2192} Enable thinkur",
                    action: {
                        permissionManager.requestScreenRecording()
                        permissionManager.openScreenRecordingSettings()
                    }
                )
            }
            .frame(maxWidth: 420)

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 6)
        .animation(Animations.glassMaterialize, value: appeared)
        .onAppear {
            appeared = true
            startPolling()
        }
        .onDisappear { stopPolling() }
    }

    private func startPolling() {
        permissionManager.checkScreenRecording()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                permissionManager.checkScreenRecording()
            }
        }
    }

    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
}
