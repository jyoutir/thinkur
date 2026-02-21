import SwiftUI
import Cocoa

// MARK: - Page 1: Permissions

struct PermissionsPage: View {
    @Environment(OnboardingViewModel.self) private var viewModel
    @Environment(PermissionManager.self) private var permissionManager

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            VStack(spacing: Spacing.sm) {
                Text("Let's get you set up")
                    .font(Typography.onboardingTitle)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text("thinkur needs a few permissions to work its magic. Your voice never leaves your Mac.")
                    .font(Typography.onboardingBody)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            GroupedSettingsSection {
                VStack(spacing: 0) {
                    PermissionRowView(
                        icon: "mic",
                        name: "Microphone",
                        description: "To hear your voice",
                        isGranted: permissionManager.microphoneGranted
                    ) {
                        Task { await viewModel.requestMicrophone() }
                    }

                    Divider()

                    PermissionRowView(
                        icon: "accessibility",
                        name: "Accessibility",
                        description: "To type into any app",
                        isGranted: permissionManager.accessibilityGranted
                    ) {
                        viewModel.openAccessibilitySettings()
                    }

                    Divider()

                    PermissionRowView(
                        icon: "keyboard",
                        name: "Input Monitoring",
                        description: "To detect your hotkey",
                        isGranted: permissionManager.inputMonitoringGranted
                    ) {
                        viewModel.openInputMonitoringSettings()
                    }
                }
            }
            .frame(maxWidth: 420)

            Spacer()

            Button {
                viewModel.nextStep()
            } label: {
                Text(viewModel.allPermissionsGranted ? "Continue" : "Grant permissions above")
                    .font(Typography.headline)
                    .frame(maxWidth: 280)
                    .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(.primary)
            .disabled(!viewModel.allPermissionsGranted)

            Spacer()
                .frame(height: Spacing.xl)
        }
        .padding(.horizontal, Spacing.xl)
        .onAppear { viewModel.startPermissionPolling() }
        .onDisappear { viewModel.stopPermissionPolling() }
    }
}

// MARK: - Page 2: Model Loading + ROI

struct ModelLoadingPage: View {
    @Environment(OnboardingViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Status area
            VStack(spacing: Spacing.md) {
                ClaudePixelSpinner(state: viewModel.isModelReady ? .success : .connecting)

                VStack(spacing: Spacing.xs) {
                    Text(viewModel.isModelReady ? "You're all set" : "Preparing your voice model")
                        .font(Typography.onboardingTitle)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.isModelReady)

                    if !viewModel.isModelReady {
                        Text(viewModel.modelLoadingMessage.isEmpty ? "This may take a moment\u{2026}" : viewModel.modelLoadingMessage)
                            .font(Typography.onboardingBody)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .contentTransition(.opacity)
                            .animation(.easeInOut(duration: 0.3), value: viewModel.modelLoadingMessage)
                    }
                }
            }

            // ROI Calculator (interactive content while waiting)
            ROICalculatorView()
                .frame(maxWidth: 720)

            Spacer()

            Button {
                viewModel.nextStep()
            } label: {
                HStack(spacing: Spacing.xs) {
                    if !viewModel.isModelReady {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text("Continue")
                        .font(Typography.headline)
                }
                .frame(maxWidth: 280)
                .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(.primary)
            .disabled(!viewModel.isModelReady)

            Spacer()
                .frame(height: Spacing.xl)
        }
        .padding(.horizontal, Spacing.xl)
    }
}

// MARK: - Page 3: Try It (Chat UI)

struct TryItPage: View {
    @Environment(OnboardingViewModel.self) private var viewModel
    @Environment(SharedAppState.self) private var sharedState
    @Environment(RecordingViewModel.self) private var recordingViewModel
    @Environment(SettingsManager.self) private var settings

    @State private var messages: [String] = []
    @State private var lastSeenVersion: Int = 0

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
                .frame(height: Spacing.sm)

            VStack(spacing: Spacing.sm) {
                Text("Try speaking to thinkur")
                    .font(Typography.onboardingTitle)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text("Press your hotkey or tap the mic below to dictate")
                    .font(Typography.onboardingBody)
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            // Chat area
            chatArea
                .frame(maxWidth: 520, maxHeight: 300)

            // Bottom bar: mic + hotkey badge + suggestion
            bottomBar
                .frame(maxWidth: 520)

            Spacer()

            Button {
                viewModel.nextStep()
            } label: {
                Text("Continue")
                    .font(Typography.headline)
                    .frame(maxWidth: 280)
                    .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(.primary)

            Spacer()
                .frame(height: Spacing.xl)
        }
        .padding(.horizontal, Spacing.xl)
        .onChange(of: sharedState.transcriptionVersion) { _, newVersion in
            if newVersion > lastSeenVersion {
                lastSeenVersion = newVersion
                let text = sharedState.lastTranscription
                if !text.isEmpty {
                    withAnimation(.spring(duration: 0.3)) {
                        messages.append(text)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    if messages.isEmpty && !isActive {
                        // Empty state
                        VStack(spacing: Spacing.md) {
                            Spacer()
                            Text("Your transcriptions will appear here\u{2026}")
                                .font(Typography.body)
                                .foregroundStyle(ColorTokens.textTertiary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                            ChatBubble(text: message)
                                .id(index)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }

                        // Listening/processing indicator
                        if isActive {
                            HStack(spacing: Spacing.xs) {
                                ClaudePixelSpinner(
                                    state: sharedState.appState == .listening ? .listening : .processing,
                                    pixelSize: 4,
                                    spacing: 2,
                                    cols: 4,
                                    rows: 2
                                )
                                Text(sharedState.appState == .listening ? "Listening\u{2026}" : "Processing\u{2026}")
                                    .font(Typography.caption)
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                            .padding(.horizontal, Spacing.md)
                            .id("activity")
                        }
                    }
                }
                .padding(Spacing.md)
            }
            .glassClear()
            .onChange(of: messages.count) { _, _ in
                withAnimation {
                    proxy.scrollTo(messages.count - 1, anchor: .bottom)
                }
            }
            .onChange(of: isActive) { _, active in
                if active {
                    withAnimation {
                        proxy.scrollTo("activity", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var isActive: Bool {
        sharedState.appState == .listening || sharedState.appState == .processing
    }

    @ViewBuilder
    private var bottomBar: some View {
        HStack(spacing: Spacing.md) {
            // Mic button
            Button {
                recordingViewModel.toggleRecording()
            } label: {
                Image(systemName: isActive ? "mic.fill" : "mic")
                    .font(.system(size: 20))
                    .foregroundStyle(isActive ? Color(red: 0.40, green: 0.90, blue: 0.55) : ColorTokens.textPrimary)
                    .frame(width: 40, height: 40)
                    .glassClear(cornerRadius: CornerRadius.button)
            }
            .buttonStyle(.plain)

            // Hotkey badge
            KeyboardShortcutBadge(
                key: HotkeyDisplayHelper.displayName(
                    keyCode: settings.hotkeyCode,
                    modifiers: NSEvent.ModifierFlags(rawValue: UInt(settings.hotkeyModifiers))
                )
            )

            Spacer()

            Text("Try: \u{201C}I need to buy three apples for twenty dollars\u{201D}")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
                .lineLimit(1)
        }
    }
}

// MARK: - Chat Bubble

private struct ChatBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Typography.body)
            .foregroundStyle(ColorTokens.textPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassClear(cornerRadius: CornerRadius.card)
    }
}

// MARK: - Page 4: Quick Settings

struct QuickSettingsPage: View {
    @Environment(OnboardingViewModel.self) private var viewModel
    @Environment(SettingsManager.self) private var settings
    @Environment(AppCoordinator.self) private var coordinator

    @State private var isRecordingHotkey = false
    @State private var eventMonitor: Any?

    private static let standardModifiers: NSEvent.ModifierFlags = [.shift, .control, .option, .command]

    var body: some View {
        @Bindable var s = settings

        VStack(spacing: Spacing.xl) {
            Spacer()

            VStack(spacing: Spacing.sm) {
                Text("Almost there")
                    .font(Typography.onboardingTitle)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text("Customize your experience. You can always change these later in Settings.")
                    .font(Typography.onboardingBody)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            GroupedSettingsSection {
                VStack(spacing: 0) {
                    // Hotkey recorder
                    SettingsRowView(icon: "keyboard", title: "Record Shortcut") {
                        Button {
                            if isRecordingHotkey {
                                stopRecordingHotkey()
                            } else {
                                startRecordingHotkey()
                            }
                        } label: {
                            KeyboardShortcutBadge(
                                key: isRecordingHotkey ? "Type shortcut\u{2026}" : currentHotkeyLabel
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Divider()

                    // Sound style
                    SoundStylePicker(selectedStyle: $s.soundStyle)

                    Divider()

                    // Push to talk
                    ToggleRow(
                        icon: "hand.tap",
                        title: "Push to Talk",
                        subtitle: "Hold to dictate, release to finish",
                        isOn: $s.hotkeyHoldMode
                    )
                }
            }
            .frame(maxWidth: 420)

            Spacer()

            Button {
                viewModel.completeSetup()
            } label: {
                Text("Start Using thinkur")
                    .font(Typography.headline)
                    .frame(maxWidth: 280)
                    .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(.primary)

            Spacer()
                .frame(height: Spacing.xl)
        }
        .padding(.horizontal, Spacing.xl)
        .onDisappear { stopRecordingHotkey() }
    }

    // MARK: - Hotkey Recording

    private var currentHotkeyLabel: String {
        HotkeyDisplayHelper.displayName(
            keyCode: settings.hotkeyCode,
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(settings.hotkeyModifiers))
        )
    }

    private func startRecordingHotkey() {
        isRecordingHotkey = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard self.isRecordingHotkey else { return }
            self.eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
                if event.type == .flagsChanged {
                    if event.keyCode == 63 && event.modifierFlags.contains(.function) {
                        self.settings.hotkeyCode = 63
                        self.settings.hotkeyModifiers = 0
                        self.coordinator.updateHotkey()
                        self.stopRecordingHotkey()
                        return nil
                    }
                    return event
                }

                let keyCode = event.keyCode
                guard keyCode != 53 else {
                    self.stopRecordingHotkey()
                    return nil
                }

                let modifiers = event.modifierFlags.intersection(Self.standardModifiers)
                self.settings.hotkeyCode = keyCode
                self.settings.hotkeyModifiers = UInt(modifiers.rawValue)
                self.coordinator.updateHotkey()
                self.stopRecordingHotkey()
                return nil
            }
        }
    }

    private func stopRecordingHotkey() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        isRecordingHotkey = false
    }
}

// MARK: - ROI Calculator

private struct ROICalculatorView: View {
    @State private var typingHoursPerDay: Double = 2.0
    @State private var hourlyRate: String = "25"

    private var rate: Double {
        Double(hourlyRate) ?? 25
    }

    private var dailyHoursSaved: Double {
        typingHoursPerDay * 0.75 // 75% savings at 4x speed
    }

    private var monthlyHoursSaved: Double {
        dailyHoursSaved * 22
    }

    private var monthlySavings: Double {
        monthlyHoursSaved * rate
    }

    private var wordsPerDay: Int {
        Int(typingHoursPerDay * 60 * 40)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("YOUR SAVINGS")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)
                .textCase(.uppercase)
                .padding(.bottom, Spacing.xxs)

            HStack(spacing: Spacing.md) {
                // Left card: Results
                resultCard

                // Right card: Controls
                controlsCard
            }
        }
    }

    private var resultCard: some View {
        VStack(spacing: Spacing.md) {
            VStack(spacing: Spacing.xxs) {
                Text("Your monthly upside")
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textSecondary)

                Text("$\(Int(monthlySavings))")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .contentTransition(.numericText(value: monthlySavings))
                    .animation(.spring(duration: 0.4), value: monthlySavings)
            }

            Divider()

            HStack(spacing: Spacing.xl) {
                VStack(spacing: Spacing.xxs) {
                    Text("\(String(format: "%.0f", monthlyHoursSaved))h")
                        .font(Typography.title2)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .contentTransition(.numericText(value: monthlyHoursSaved))
                        .animation(.spring(duration: 0.4), value: monthlyHoursSaved)
                    Text("hours saved")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                }

                VStack(spacing: Spacing.xxs) {
                    Text("\(wordsPerDay)")
                        .font(Typography.title2)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .contentTransition(.numericText(value: Double(wordsPerDay)))
                        .animation(.spring(duration: 0.4), value: wordsPerDay)
                    Text("words / day")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }

            Text("Buy once for $29. Keep the upside.")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text("Typing time per day")
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Spacer()
                    Text("\(String(format: "%.1f", typingHoursPerDay))h / day")
                        .font(Typography.headline)
                        .foregroundStyle(ColorTokens.textSecondary)
                }

                Slider(value: $typingHoursPerDay, in: 0.5...8.0, step: 0.5)
                    .tint(.accentColor)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Hourly value of your time")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)

                HStack(spacing: Spacing.xxs) {
                    Text("$")
                        .font(Typography.headline)
                        .foregroundStyle(ColorTokens.textSecondary)

                    TextField("25", text: $hourlyRate)
                        .textFieldStyle(.plain)
                        .font(Typography.headline)
                        .frame(width: 60)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.xxs)
                        .glassClear(cornerRadius: CornerRadius.field)

                    Text("/ hour")
                        .font(Typography.callout)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }

            Text("Assumes 4x dictation speed")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .glassCard()
    }
}
