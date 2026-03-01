import SwiftUI

struct MeetingSetupView: View {
    @Environment(PermissionManager.self) private var permissionManager
    @Environment(SettingsManager.self) private var settings
    @State private var pollingTimer: Timer?
    @State private var appeared = false
    @State private var apiKeyInput = ""
    @State private var isValidatingKey = false
    @State private var keyValidationResult: Bool?
    @State private var showKeyInput = false

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

                Text("Two quick steps to start recording meetings.")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Both steps in a single card
            GroupedSettingsSection {
                // Step 1: Screen Recording
                PermissionRowView(
                    icon: "tv.and.mediabox",
                    name: "Screen Recording",
                    description: "Captures audio from calls and apps",
                    isGranted: permissionManager.screenRecordingGranted,
                    helpText: "System Settings \u{2192} Privacy & Security \u{2192} Screen & System Audio Recording \u{2192} Enable thinkur",
                    action: {
                        permissionManager.requestScreenRecording()
                        permissionManager.openScreenRecordingSettings()
                    }
                )

                Divider()
                    .padding(.leading, 28 + Spacing.sm + Spacing.md)

                // Step 2: Deepgram API Key
                deepgramRow
            }
            .frame(maxWidth: 420)

            // Expand area for key input when active
            if showKeyInput && !settings.hasDeepgramKey {
                VStack(spacing: Spacing.sm) {
                    HStack(spacing: Spacing.sm) {
                        TextField("Paste your API key", text: $apiKeyInput)
                            .textFieldStyle(.plain)
                            .font(Typography.body)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .materialClear()

                        Button {
                            Task { await validateAndSaveKey() }
                        } label: {
                            Group {
                                if isValidatingKey {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text("Connect")
                                        .font(Typography.caption)
                                        .fontWeight(.medium)
                                }
                            }
                            .frame(width: 60)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(settings.accentUITint)
                        .controlSize(.small)
                        .disabled(apiKeyInput.isEmpty || isValidatingKey)
                    }

                    if keyValidationResult == false {
                        Text("Invalid key \u{2014} check and try again.")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: 420)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 6)
        .animation(Animations.glassMaterialize, value: appeared)
        .animation(.easeInOut(duration: 0.2), value: showKeyInput)
        .onAppear {
            appeared = true
            startPolling()
        }
        .onDisappear { stopPolling() }
    }

    // MARK: - Deepgram Row

    @ViewBuilder
    private var deepgramRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "waveform.badge.mic")
                    .font(.system(size: 18))
                    .foregroundStyle(settings.accentUITint)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Deepgram API Key")
                        .font(Typography.headline)
                        .foregroundStyle(ColorTokens.textPrimary)

                    Text("Transcription & speaker detection")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                }

                Spacer()

                if settings.hasDeepgramKey {
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.success)
                } else {
                    Button(showKeyInput ? "I have a key" : "Set up") {
                        if showKeyInput {
                            // Already showing input, no-op (button label just confirms state)
                        } else {
                            withAnimation { showKeyInput = true }
                        }
                    }
                    .controlSize(.small)
                    .disabled(showKeyInput)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)

            // Inline help when expanded but key not yet entered
            if showKeyInput && !settings.hasDeepgramKey {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Link(destination: URL(string: "https://console.deepgram.com/signup")!) {
                        HStack(spacing: 4) {
                            Text("Get a free API key")
                                .font(Typography.caption)
                                .fontWeight(.medium)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(settings.accentUITint)
                    }

                    Text("$200 free credit on signup (~770 hours)")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.leading, 28 + Spacing.sm)
                .padding(.bottom, Spacing.sm)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Connected state: show remove option
            if settings.hasDeepgramKey {
                Button {
                    settings.deepgramApiKey = ""
                    apiKeyInput = ""
                    keyValidationResult = nil
                    showKeyInput = false
                } label: {
                    Text("Remove key")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Spacing.md)
                .padding(.leading, 28 + Spacing.sm)
                .padding(.bottom, Spacing.sm)
            }
        }
    }

    // MARK: - Actions

    private func validateAndSaveKey() async {
        isValidatingKey = true
        keyValidationResult = nil

        let client = DeepgramClient()
        let valid = await client.validate(apiKey: apiKeyInput)

        isValidatingKey = false
        keyValidationResult = valid

        if valid {
            settings.deepgramApiKey = apiKeyInput
            apiKeyInput = ""
            withAnimation { showKeyInput = false }
        }
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
