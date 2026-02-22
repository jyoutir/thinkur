import SwiftUI
import Cocoa

// MARK: - Page 1: Permissions

struct PermissionsPage: View {
    @Environment(OnboardingViewModel.self) private var viewModel
    @Environment(PermissionManager.self) private var permissionManager
    @Environment(SettingsManager.self) private var settings

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            VStack(spacing: Spacing.sm) {
                Text("Set up thinkur")
                    .font(Typography.onboardingTitle)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text("Grant three permissions. Your voice stays on your Mac.")
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
                        isGranted: permissionManager.microphoneGranted,
                        helpText: "Audio input for on-device speech processing."
                    ) {
                        Task { await viewModel.requestMicrophone() }
                    }

                    Divider()

                    PermissionRowView(
                        icon: "accessibility",
                        name: "Accessibility",
                        description: "To type into any app",
                        isGranted: permissionManager.accessibilityGranted,
                        helpText: "Injects transcribed text into the active app."
                    ) {
                        viewModel.openAccessibilitySettings()
                    }

                    Divider()

                    PermissionRowView(
                        icon: "keyboard",
                        name: "Input Monitoring",
                        description: "To detect your hotkey",
                        isGranted: permissionManager.inputMonitoringGranted,
                        helpText: "Detects your hotkey to activate listening mode."
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
                Text(viewModel.allPermissionsGranted ? "Continue" : "Grant required permissions")
                    .font(Typography.headline)
                    .frame(maxWidth: 280)
                    .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(settings.accentUITint)
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
    @Environment(SettingsManager.self) private var settings

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Status area
            VStack(spacing: Spacing.md) {
                ClaudePixelSpinner(state: viewModel.isModelReady ? .success : .connecting)

                VStack(spacing: Spacing.xs) {
                    Text(viewModel.isModelReady ? "Model ready" : "Preparing voice model")
                        .font(Typography.onboardingTitle)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.isModelReady)

                    if !viewModel.isModelReady {
                        Text(viewModel.modelLoadingMessage.isEmpty ? "Almost ready\u{2026}" : viewModel.modelLoadingMessage)
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
            .tint(settings.accentUITint)
            .disabled(!viewModel.isModelReady)

            Spacer()
                .frame(height: Spacing.xl)
        }
        .padding(.horizontal, Spacing.xl)
    }
}

// MARK: - Page 3: Try It (App-Themed Demo)

private enum DemoContext: Int, CaseIterable, Identifiable {
    case terminal = 0
    case browser = 1
    case messages = 2
    case slack = 3
    case notes = 4

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .terminal: "Terminal"
        case .browser: "Firefox"
        case .messages: "Messages"
        case .slack: "Slack"
        case .notes: "Notes"
        }
    }

    var bundleIdentifier: String? {
        switch self {
        case .terminal: "com.apple.Terminal"
        case .browser: "org.mozilla.firefox"
        case .messages: "com.apple.MobileSMS"
        case .slack: "com.tinyspeck.slackmacgap"
        case .notes: "com.apple.Notes"
        }
    }

    var fallbackIcon: String {
        switch self {
        case .terminal: "terminal"
        case .browser: "globe"
        case .messages: "message"
        case .slack: "number"
        case .notes: "note.text"
        }
    }

    var appIcon: NSImage? {
        guard let bundleID = bundleIdentifier,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
    }
}

private let exampleSentences: [String] = [
    "I need to buy three apples for twenty dollars",
    "Dear Sarah comma thanks for the update period",
    "First comma check the logs period second comma restart the server",
    "The meeting is at two thirty PM on January fifteenth",
    "Can you send me the report question mark",
]

struct TryItPage: View {
    @Environment(OnboardingViewModel.self) private var viewModel
    @Environment(SharedAppState.self) private var sharedState
    @Environment(RecordingViewModel.self) private var recordingViewModel
    @Environment(SettingsManager.self) private var settings

    @State private var messages: [String] = []
    @State private var lastSeenVersion: Int = 0
    @State private var selectedContext: DemoContext = .terminal
    @State private var suggestionIndex: Int = 0
    @State private var suggestionTimer: Timer?

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            VStack(spacing: Spacing.sm) {
                Text("Try thinkur in real apps")
                    .font(Typography.onboardingTitle)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text(messages.isEmpty
                     ? "Press \(hotkeyLabel) and speak."
                     : "Press your hotkey or tap mic.")
                    .font(Typography.onboardingBody)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: messages.isEmpty)
            }

            // Context selector
            contextSelector
                .frame(maxWidth: 520)

            // App-themed demo area
            demoArea
                .frame(maxWidth: 520, minHeight: 180, maxHeight: 260)

            // Bottom bar: mic + hotkey badge + suggestion
            bottomBar
                .frame(maxWidth: 520)

            Spacer(minLength: Spacing.sm)

            Button {
                viewModel.nextStep()
            } label: {
                Text(messages.isEmpty ? "Dictate something to continue" : "Continue")
                    .font(Typography.headline)
                    .frame(maxWidth: 280)
                    .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(settings.accentUITint)
            .disabled(messages.isEmpty)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.xl)
        .onKeyPress(.leftArrow) {
            selectPrevious()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            selectNext()
            return .handled
        }
        .onChange(of: sharedState.transcriptionVersion) { _, newVersion in
            if newVersion > lastSeenVersion {
                lastSeenVersion = newVersion
                let text = sharedState.lastTranscription
                if !text.isEmpty {
                    withAnimation(.spring(duration: 0.3)) {
                        messages.append(text)
                    }
                    cycleSuggestion()
                }
            }
        }
        .onAppear { startSuggestionTimer() }
        .onDisappear { stopSuggestionTimer() }
    }

    // MARK: - Context Selector

    @ViewBuilder
    private var contextSelector: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(DemoContext.allCases) { context in
                let isSelected = selectedContext == context
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        selectedContext = context
                    }
                } label: {
                    HStack(spacing: 4) {
                        if let appIcon = context.appIcon {
                            Image(nsImage: appIcon)
                                .resizable()
                                .frame(width: 24, height: 24)
                        } else {
                            Image(systemName: context.fallbackIcon)
                                .font(.system(size: 10))
                        }
                        Text(context.label)
                            .font(Typography.caption)
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs + 2)
                    .background(
                        isSelected ? ColorTokens.textPrimary.opacity(0.12) : Color.clear,
                        in: .capsule
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                isSelected ? ColorTokens.textPrimary.opacity(0.3) : ColorTokens.border,
                                lineWidth: 1
                            )
                    )
                    .foregroundStyle(isSelected ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Demo Area

    @ViewBuilder
    private var demoArea: some View {
        Group {
            switch selectedContext {
            case .terminal:
                TerminalDemoView(messages: messages, isActive: isActive, appState: sharedState.appState)
            case .browser:
                BrowserDemoView(messages: messages, isActive: isActive, appState: sharedState.appState)
            case .messages:
                MessagesDemoView(messages: messages, isActive: isActive, appState: sharedState.appState)
            case .slack:
                SlackDemoView(messages: messages, isActive: isActive, appState: sharedState.appState)
            case .notes:
                NotesDemoView(messages: messages, isActive: isActive, appState: sharedState.appState)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .animation(.spring(duration: 0.25), value: selectedContext)
        .id(selectedContext)
    }

    private var isActive: Bool {
        sharedState.appState == .listening || sharedState.appState == .processing
    }

    // MARK: - Bottom Bar

    @ViewBuilder
    private var bottomBar: some View {
        HStack(spacing: Spacing.md) {
            Button {
                recordingViewModel.toggleRecording()
            } label: {
                Image(systemName: isActive ? "mic.fill" : "mic")
                    .font(.system(size: 20))
                    .foregroundStyle(isActive ? settings.accentColor : ColorTokens.textPrimary)
                    .frame(width: 40, height: 40)
                    .glassClear(cornerRadius: CornerRadius.button)
            }
            .buttonStyle(.plain)

            KeyboardShortcutBadge(
                key: HotkeyDisplayHelper.displayName(
                    keyCode: settings.hotkeyCode,
                    modifiers: NSEvent.ModifierFlags(rawValue: UInt(settings.hotkeyModifiers))
                )
            )

            Spacer()

            Text("Try: \u{201C}\(exampleSentences[suggestionIndex])\u{201D}")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
                .lineLimit(1)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: suggestionIndex)
        }
    }

    // MARK: - Helpers

    private var hotkeyLabel: String {
        HotkeyDisplayHelper.displayName(
            keyCode: settings.hotkeyCode,
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(settings.hotkeyModifiers))
        )
    }

    private func selectPrevious() {
        withAnimation(.spring(duration: 0.25)) {
            let prev = selectedContext.rawValue - 1
            selectedContext = DemoContext(rawValue: prev >= 0 ? prev : DemoContext.allCases.count - 1)!
        }
    }

    private func selectNext() {
        withAnimation(.spring(duration: 0.25)) {
            let next = selectedContext.rawValue + 1
            selectedContext = DemoContext(rawValue: next < DemoContext.allCases.count ? next : 0)!
        }
    }

    private func cycleSuggestion() {
        suggestionIndex = (suggestionIndex + 1) % exampleSentences.count
        restartSuggestionTimer()
    }

    private func startSuggestionTimer() {
        suggestionTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            Task { @MainActor in
                withAnimation {
                    suggestionIndex = (suggestionIndex + 1) % exampleSentences.count
                }
            }
        }
    }

    private func stopSuggestionTimer() {
        suggestionTimer?.invalidate()
        suggestionTimer = nil
    }

    private func restartSuggestionTimer() {
        stopSuggestionTimer()
        startSuggestionTimer()
    }
}

// MARK: - Terminal Demo View

private struct TerminalDemoView: View {
    let messages: [String]
    let isActive: Bool
    let appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack(spacing: spacing6) {
                Circle().fill(Color(hex: "FF5F57")).frame(width: 10, height: 10)
                Circle().fill(Color(hex: "FFBD2E")).frame(width: 10, height: 10)
                Circle().fill(Color(hex: "28C840")).frame(width: 10, height: 10)
                Spacer()
                Text("Terminal")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                // Balance the dots
                Color.clear.frame(width: 38, height: 10)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(Color(hex: "3A3A3C"))

            // Terminal content
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        if messages.isEmpty && !isActive {
                            HStack(spacing: 0) {
                                Text("~ $ ")
                                    .foregroundStyle(Color(hex: "28C840"))
                                cursor
                            }
                            .padding(.top, Spacing.xs)
                        } else {
                            ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack(spacing: 0) {
                                        Text("~ $ ")
                                            .foregroundStyle(Color(hex: "28C840"))
                                        Text(message)
                                            .foregroundStyle(.white)
                                    }
                                }
                                .id(index)
                                .transition(.opacity)
                            }

                            if isActive {
                                HStack(spacing: 0) {
                                    Text("~ $ ")
                                        .foregroundStyle(Color(hex: "28C840"))
                                    Text(appState == .listening ? "listening..." : "processing...")
                                        .foregroundStyle(.white.opacity(0.4))
                                    cursor
                                }
                                .id("active")
                            } else {
                                HStack(spacing: 0) {
                                    Text("~ $ ")
                                        .foregroundStyle(Color(hex: "28C840"))
                                    cursor
                                }
                            }
                        }
                    }
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.sm)
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation { proxy.scrollTo(messages.count - 1, anchor: .bottom) }
                }
            }
            .background(Color(hex: "1E1E1E"))
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var cursor: some View {
        Rectangle()
            .fill(.white.opacity(0.7))
            .frame(width: 7, height: 14)
    }

    private let spacing6: CGFloat = 6
}

// MARK: - Browser Demo View (Email Compose)

private struct BrowserDemoView: View {
    let messages: [String]
    let isActive: Bool
    let appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Browser chrome
            HStack(spacing: Spacing.xs) {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "chevron.left")
                    Image(systemName: "chevron.right")
                    Image(systemName: "arrow.clockwise")
                }
                .font(.system(size: 10))
                .foregroundStyle(ColorTokens.textTertiary)

                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(ColorTokens.textTertiary)
                    Text("mail.google.com/compose")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.xxs)
                .background(ColorTokens.border.opacity(0.3), in: .capsule)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(.ultraThinMaterial)

            // Email compose area
            VStack(alignment: .leading, spacing: 0) {
                // Email header fields
                emailField(label: "To", value: "sarah@company.com")
                Divider()
                emailField(label: "Subject", value: "Project Update")
                Divider()

                // Email body
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            if messages.isEmpty && !isActive {
                                Text("Compose your email\u{2026}")
                                    .foregroundStyle(ColorTokens.textTertiary)
                                    .padding(.top, Spacing.xs)
                            } else {
                                ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                                    Text(message)
                                        .foregroundStyle(ColorTokens.textPrimary)
                                        .id(index)
                                        .transition(.opacity)
                                }

                                if isActive {
                                    HStack(spacing: Spacing.xxs) {
                                        ClaudePixelSpinner(
                                            state: appState == .listening ? .listening : .processing,
                                            pixelSize: 3,
                                            spacing: 1,
                                            cols: 4,
                                            rows: 2
                                        )
                                        Text(appState == .listening ? "Listening\u{2026}" : "Processing\u{2026}")
                                            .foregroundStyle(ColorTokens.textTertiary)
                                    }
                                    .font(Typography.caption)
                                    .id("active")
                                }
                            }
                        }
                        .font(Typography.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                    }
                    .onChange(of: messages.count) { _, _ in
                        withAnimation { proxy.scrollTo(messages.count - 1, anchor: .bottom) }
                    }
                }
            }
            .background(ColorTokens.cardBackground.opacity(0.3))
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .strokeBorder(ColorTokens.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func emailField(label: String, value: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
                .frame(width: 50, alignment: .trailing)
            Text(value)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textPrimary)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs + 2)
    }
}

// MARK: - Messages Demo View

private struct MessagesDemoView: View {
    let messages: [String]
    let isActive: Bool
    let appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                VStack(spacing: 2) {
                    Text("Sarah")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ColorTokens.textPrimary)
                }
                Spacer()
            }
            .padding(.vertical, Spacing.xs)
            .background(.ultraThinMaterial)

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .trailing, spacing: Spacing.xs) {
                        if messages.isEmpty && !isActive {
                            VStack(spacing: Spacing.sm) {
                                Spacer()
                                Text("Your messages will appear here\u{2026}")
                                    .font(Typography.body)
                                    .foregroundStyle(ColorTokens.textTertiary)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, minHeight: 160)
                        } else {
                            // Existing incoming message for context
                            HStack {
                                Text("Hey, can you send me the project update?")
                                    .font(Typography.body)
                                    .foregroundStyle(ColorTokens.textPrimary)
                                    .padding(.horizontal, Spacing.sm)
                                    .padding(.vertical, Spacing.xs)
                                    .background(ColorTokens.border.opacity(0.5), in: messageBubble)
                                Spacer(minLength: 60)
                            }
                            .padding(.top, Spacing.xs)

                            ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                                HStack {
                                    Spacer(minLength: 60)
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(message)
                                            .font(Typography.body)
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, Spacing.sm)
                                            .padding(.vertical, Spacing.xs)
                                            .background(Color.accentColor, in: messageBubble)

                                        Text(timeLabel(for: index))
                                            .font(.system(size: 9))
                                            .foregroundStyle(ColorTokens.textTertiary)
                                    }
                                }
                                .id(index)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                ))
                            }

                            if isActive {
                                HStack {
                                    Spacer(minLength: 60)
                                    HStack(spacing: Spacing.xxs) {
                                        ClaudePixelSpinner(
                                            state: appState == .listening ? .listening : .processing,
                                            pixelSize: 3,
                                            spacing: 1,
                                            cols: 4,
                                            rows: 2
                                        )
                                    }
                                    .padding(.horizontal, Spacing.sm)
                                    .padding(.vertical, Spacing.xs)
                                    .background(Color.accentColor.opacity(0.5), in: messageBubble)
                                }
                                .id("active")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.bottom, Spacing.sm)
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation { proxy.scrollTo(messages.count - 1, anchor: .bottom) }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .strokeBorder(ColorTokens.border, lineWidth: 1)
        )
        .background(ColorTokens.cardBackground.opacity(0.3), in: RoundedRectangle(cornerRadius: CornerRadius.card))
    }

    private var messageBubble: RoundedRectangle {
        RoundedRectangle(cornerRadius: 16)
    }

    private func timeLabel(for index: Int) -> String {
        let base = 41 + index
        return "10:\(String(format: "%02d", base % 60)) AM"
    }
}

// MARK: - Slack Demo View

private struct SlackDemoView: View {
    let messages: [String]
    let isActive: Bool
    let appState: AppState

    private let avatarColors: [Color] = [
        Color(hex: "E01E5A"),
        Color(hex: "36C5F0"),
        Color(hex: "2EB67D"),
        Color(hex: "ECB22E"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Channel header
            HStack(spacing: Spacing.xxs) {
                Image(systemName: "number")
                    .font(.system(size: 12, weight: .bold))
                Text("general")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
            }
            .foregroundStyle(ColorTokens.textPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(.ultraThinMaterial)

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        if messages.isEmpty && !isActive {
                            VStack(spacing: Spacing.sm) {
                                Spacer()
                                Text("Your messages will appear here\u{2026}")
                                    .font(Typography.body)
                                    .foregroundStyle(ColorTokens.textTertiary)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, minHeight: 160)
                        } else {
                            // Context message from another user
                            slackMessage(
                                avatar: Color(hex: "36C5F0"),
                                name: "Alice",
                                text: "Can someone check the deployment status?",
                                time: "10:38 AM"
                            )

                            ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                                slackMessage(
                                    avatar: Color(hex: "2EB67D"),
                                    name: "You",
                                    text: message,
                                    time: "10:\(String(format: "%02d", 41 + index)) AM"
                                )
                                .id(index)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                ))
                            }

                            if isActive {
                                HStack(alignment: .top, spacing: Spacing.xs) {
                                    Circle()
                                        .fill(Color(hex: "2EB67D"))
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Text("Y")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(.white)
                                        )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("You")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(ColorTokens.textPrimary)
                                        HStack(spacing: Spacing.xxs) {
                                            ClaudePixelSpinner(
                                                state: appState == .listening ? .listening : .processing,
                                                pixelSize: 3,
                                                spacing: 1,
                                                cols: 4,
                                                rows: 2
                                            )
                                            Text(appState == .listening ? "Listening\u{2026}" : "Processing\u{2026}")
                                                .font(Typography.caption)
                                                .foregroundStyle(ColorTokens.textTertiary)
                                        }
                                    }
                                }
                                .id("active")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.sm)
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation { proxy.scrollTo(messages.count - 1, anchor: .bottom) }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .strokeBorder(ColorTokens.border, lineWidth: 1)
        )
        .background(ColorTokens.cardBackground.opacity(0.3), in: RoundedRectangle(cornerRadius: CornerRadius.card))
    }

    @ViewBuilder
    private func slackMessage(avatar: Color, name: String, text: String, time: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Circle()
                .fill(avatar)
                .frame(width: 28, height: 28)
                .overlay(
                    Text(String(name.prefix(1)))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xxs) {
                    Text(name)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text(time)
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                Text(text)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)
            }
        }
    }
}

// MARK: - Notes Demo View

private struct NotesDemoView: View {
    let messages: [String]
    let isActive: Bool
    let appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Notes toolbar
            HStack {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.accentColor)
                    Text("Notes")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.accentColor)
                }
                Spacer()
                HStack(spacing: Spacing.md) {
                    Image(systemName: "square.and.pencil")
                    Image(systemName: "ellipsis.circle")
                }
                .font(.system(size: 13))
                .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(.ultraThinMaterial)

            // Note content
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        // Note title
                        Text("Meeting Notes")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(ColorTokens.textPrimary)
                            .padding(.top, Spacing.xs)

                        Text("February 21, 2026")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textTertiary)

                        if messages.isEmpty && !isActive {
                            Text("Start dictating your notes\u{2026}")
                                .foregroundStyle(ColorTokens.textTertiary)
                                .padding(.top, Spacing.xxs)
                        } else {
                            ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                                Text(message)
                                    .font(Typography.body)
                                    .foregroundStyle(ColorTokens.textPrimary)
                                    .id(index)
                                    .transition(.opacity)
                            }

                            if isActive {
                                HStack(spacing: Spacing.xxs) {
                                    ClaudePixelSpinner(
                                        state: appState == .listening ? .listening : .processing,
                                        pixelSize: 3,
                                        spacing: 1,
                                        cols: 4,
                                        rows: 2
                                    )
                                    Text(appState == .listening ? "Listening\u{2026}" : "Processing\u{2026}")
                                        .foregroundStyle(ColorTokens.textTertiary)
                                }
                                .font(Typography.caption)
                                .id("active")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation { proxy.scrollTo(messages.count - 1, anchor: .bottom) }
                }
            }
            .background(ColorTokens.cardBackground.opacity(0.3))
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .strokeBorder(ColorTokens.border, lineWidth: 1)
        )
    }
}

// MARK: - Page 4: Quick Settings

@MainActor
private final class HotkeyRecorderState: ObservableObject {
    @Published var isRecording = false
    private var eventMonitor: Any?

    private static let standardModifiers: NSEvent.ModifierFlags = [.shift, .control, .option, .command]

    func startRecording(settings: SettingsManager, coordinator: AppCoordinator) {
        isRecording = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, self.isRecording else { return }
            self.eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
                guard let self else { return event }
                if event.type == .flagsChanged {
                    // Capture Fn/Globe key (keyCode 63) on either press or release
                    if event.keyCode == 63 {
                        settings.hotkeyCode = 63
                        settings.hotkeyModifiers = 0
                        coordinator.updateHotkey()
                        self.stopRecording()
                        return nil
                    }
                    return event
                }

                let keyCode = event.keyCode
                guard keyCode != 53 else {
                    self.stopRecording()
                    return nil
                }

                let modifiers = event.modifierFlags.intersection(Self.standardModifiers)
                settings.hotkeyCode = keyCode
                settings.hotkeyModifiers = UInt(modifiers.rawValue)
                coordinator.updateHotkey()
                self.stopRecording()
                return nil
            }
        }
    }

    func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        isRecording = false
    }
}

struct QuickSettingsPage: View {
    @Environment(OnboardingViewModel.self) private var viewModel
    @Environment(SettingsManager.self) private var settings
    @Environment(AppCoordinator.self) private var coordinator

    @StateObject private var recorder = HotkeyRecorderState()

    var body: some View {
        @Bindable var s = settings

        VStack(spacing: Spacing.xl) {
            Spacer()

            VStack(spacing: Spacing.sm) {
                Text("Quick settings")
                    .font(Typography.onboardingTitle)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text("Choose your shortcut and recording style.")
                    .font(Typography.onboardingBody)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            VStack(spacing: Spacing.md) {
                GroupedSettingsSection {
                    VStack(spacing: 0) {
                        // Hotkey recorder
                        SettingsRowView(icon: "keyboard", title: "Record Shortcut") {
                            Button {
                                if recorder.isRecording {
                                    recorder.stopRecording()
                                } else {
                                    recorder.startRecording(settings: settings, coordinator: coordinator)
                                }
                            } label: {
                                KeyboardShortcutBadge(
                                    key: recorder.isRecording ? "Type shortcut\u{2026}" : currentHotkeyLabel
                                )
                            }
                            .buttonStyle(.plain)
                        }

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

                GroupedSettingsSection {
                    VStack(spacing: 0) {
                        SoundStylePicker(selectedStyle: $s.soundStyle)

                        Divider()

                        AccentColorPicker(selectedColor: $s.accentColorName)
                    }
                }
            }
            .frame(maxWidth: 420)

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
            .tint(settings.accentUITint)

            Spacer()
                .frame(height: Spacing.xl)
        }
        .padding(.horizontal, Spacing.xl)
        .onDisappear { recorder.stopRecording() }
    }

    // MARK: - Hotkey Recording

    private var currentHotkeyLabel: String {
        HotkeyDisplayHelper.displayName(
            keyCode: settings.hotkeyCode,
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(settings.hotkeyModifiers))
        )
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
        typingHoursPerDay * 0.5 // 50% savings at 2x speed (80 wpm typing vs ~160 wpm dictation)
    }

    private var monthlyHoursSaved: Double {
        dailyHoursSaved * 22
    }

    private var monthlySavings: Double {
        monthlyHoursSaved * rate
    }

    private var wordsPerDay: Int {
        Int(typingHoursPerDay * 60 * 80)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("VALUE")
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
                Text("Monthly upside")
                    .font(Typography.callout)
                    .foregroundStyle(ColorTokens.textSecondary)

                Text("£\(Int(monthlySavings))")
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

        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                Text("Your hourly value")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textPrimary)

                HStack(spacing: Spacing.xxs) {
                    Text("£")
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

            Text("Assumes 80 wpm typing \u{2014} faster than 95% of people")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassCard()
    }
}
