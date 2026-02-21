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

// MARK: - Page 2: Value + Demo + Setup

struct ValueDemoPage: View {
    @Environment(OnboardingViewModel.self) private var viewModel
    @Environment(SettingsManager.self) private var settings
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(SharedAppState.self) private var sharedState

    @State private var isRecordingHotkey = false
    @State private var eventMonitor: Any?

    private static let standardModifiers: NSEvent.ModifierFlags = [.shift, .control, .option, .command]

    var body: some View {
        @Bindable var s = settings

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                // Section A: ROI Calculator
                ROICalculatorView()

                // Section B: Try It Yourself
                tryItSection

                // Section C: Quick Settings
                quickSettingsSection

                // CTA
                HStack {
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
                }
                .padding(.bottom, Spacing.lg)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.lg)
        }
        .onDisappear { stopRecordingHotkey() }
    }

    // MARK: - Try It

    @ViewBuilder
    private var tryItSection: some View {
        GroupedSettingsSection(title: "Try It Yourself") {
            if !sharedState.isModelReady {
                VStack(spacing: Spacing.md) {
                    ClaudePixelSpinner(state: .connecting)
                    Text(sharedState.modelLoadingMessage.isEmpty ? "Loading model\u{2026}" : sharedState.modelLoadingMessage)
                        .font(Typography.callout)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xl)
            } else {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Press your hotkey or click the mic to try it")
                        .font(Typography.body)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.sm)

                    Text(sharedState.lastTranscription.isEmpty ? "Your transcription will appear here\u{2026}" : sharedState.lastTranscription)
                        .font(Typography.body)
                        .foregroundStyle(sharedState.lastTranscription.isEmpty ? ColorTokens.textTertiary : ColorTokens.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                        .padding(Spacing.md)
                        .glassClear()

                    Text("Try saying: \"I need to buy three apples for twenty dollars\"")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.bottom, Spacing.sm)
                }
            }
        }
    }

    // MARK: - Quick Settings

    @ViewBuilder
    private var quickSettingsSection: some View {
        @Bindable var s = settings

        GroupedSettingsSection(title: "Quick Settings") {
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
    }

    // MARK: - Hotkey Recording

    private var currentHotkeyLabel: String {
        hotkeyDisplayName(
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

    // MARK: - Key Name Display

    private func modifierSymbols(for flags: NSEvent.ModifierFlags) -> String {
        var s = ""
        if flags.contains(.control) { s += "\u{2303}" }
        if flags.contains(.option) { s += "\u{2325}" }
        if flags.contains(.shift) { s += "\u{21E7}" }
        if flags.contains(.command) { s += "\u{2318}" }
        return s
    }

    private func hotkeyDisplayName(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        let mods = modifierSymbols(for: modifiers)
        let key = keyName(for: keyCode)
        return mods.isEmpty ? key : "\(mods)\(key)"
    }

    private func keyName(for keyCode: UInt16) -> String {
        let specialKeys: [UInt16: String] = [
            48: "Tab", 49: "Space", 36: "Return", 51: "Delete",
            53: "Esc", 76: "Enter", 123: "\u{2190}", 124: "\u{2192}",
            125: "\u{2193}", 126: "\u{2191}", 115: "Home", 119: "End",
            116: "Page Up", 121: "Page Down", 117: "\u{2326}",
            63: "Fn", 122: "F1", 120: "F2", 99: "F3", 118: "F4",
            96: "F5", 97: "F6", 98: "F7", 100: "F8",
            101: "F9", 109: "F10", 103: "F11", 111: "F12",
        ]
        if let name = specialKeys[keyCode] { return name }

        let charKeys: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\",
            43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
            50: "`", 10: "\u{00A7}",
        ]
        if let name = charKeys[keyCode] { return name }

        return "Key \(keyCode)"
    }
}

// MARK: - ROI Calculator

private struct ROICalculatorView: View {
    @State private var typingHoursPerDay: Double = 2.0
    @State private var hourlyRate: String = "50"

    private var rate: Double {
        Double(hourlyRate) ?? 50
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
                    .foregroundStyle(Color(red: 0.4, green: 0.9, blue: 0.55))
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
                    .tint(Color(red: 0.4, green: 0.9, blue: 0.55))
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Hourly value of your time")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)

                HStack(spacing: Spacing.xxs) {
                    Text("$")
                        .font(Typography.headline)
                        .foregroundStyle(ColorTokens.textSecondary)

                    TextField("50", text: $hourlyRate)
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

            Text("Assumes 4x speed and 22 workdays/month")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .glassCard()
    }
}
