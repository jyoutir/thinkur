import Cocoa
import SwiftUI

/// Floating NSPanel that displays the indicator at the bottom center of the screen.
/// Uses .nonactivatingPanel so it never steals focus from the app the user is typing in.
///
/// The panel is a fixed 200×50 transparent container — all visual sizing and animation
/// is handled by SwiftUI inside FloatingIndicatorView.
final class FloatingIndicatorPanel: NSPanel {
    private let amplitudeProvider: AudioAmplitudeProvider
    private let stateHolder = StateHolder()
    private var screenObserver: NSObjectProtocol?

    /// Fixed panel size — large enough to contain the biggest state (listening: 130×32)
    private static let fixedSize = NSSize(width: 200, height: 50)

    /// Called when the user clicks the idle pill.
    var onTap: (() -> Void)? {
        get { stateHolder.onTap }
        set { stateHolder.onTap = newValue }
    }

    init(amplitudeProvider: AudioAmplitudeProvider, settings: SettingsManager, themeMode: ThemeMode = .dark) {
        self.amplitudeProvider = amplitudeProvider

        let size = Self.fixedSize

        // Position at absolute bottom center of the screen, ignoring Dock/menu bar insets.
        // Using .frame (not .visibleFrame) so the bar hugs the screen edge even when
        // the Dock is at the bottom — the .floating window level renders above the Dock.
        // Fall back to primary display if NSScreen.main is nil (no key window yet at launch).
        let screenFrame = (NSScreen.main ?? NSScreen.screens.first)?.frame ?? .zero
        let originX = screenFrame.midX - size.width / 2
        let originY = screenFrame.minY + 8

        super.init(
            contentRect: NSRect(x: originX, y: originY, width: size.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false  // SwiftUI handles shadows
        ignoresMouseEvents = false  // Allow hover/click when idle
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
        self.appearance = NSAppearance(named: themeMode == .dark ? .darkAqua : .aqua)

        let indicatorView = FloatingIndicatorView(stateHolder: stateHolder)
            .environment(amplitudeProvider)
            .environment(settings)

        contentView = NSHostingView(rootView: indicatorView)

        // Recenter when displays connect/disconnect
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.recenter()
        }
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    func updateAppearance(for themeMode: ThemeMode) {
        self.appearance = NSAppearance(named: themeMode == .dark ? .darkAqua : .aqua)
    }

    func setState(_ state: SpinnerState) {
        if stateHolder.currentState != state {
            stateHolder.currentState = state
        }
        // Only accept mouse events when idle (hover/click on pill).
        // During listening/processing, pass events through to windows below.
        let shouldIgnoreMouse = state != .idle
        if ignoresMouseEvents != shouldIgnoreMouse {
            ignoresMouseEvents = shouldIgnoreMouse
        }
    }

    func show() {
        recenter()
        orderFrontRegardless()
    }

    private func recenter() {
        let size = Self.fixedSize
        // Prefer the screen with keyboard focus; fall back to the primary display.
        let screenFrame = (NSScreen.main ?? NSScreen.screens.first)?.frame ?? .zero
        let originX = screenFrame.midX - size.width / 2
        let originY = screenFrame.minY + 8
        setFrame(NSRect(x: originX, y: originY, width: size.width, height: size.height), display: true)
    }
}

// MARK: - State Holder

@MainActor
final class StateHolder: ObservableObject {
    @Published var currentState: SpinnerState = .idle
    var onTap: (() -> Void)?
}

// MARK: - Unified Indicator View

/// All visual sizing and animation is handled here via SwiftUI.
/// The NSPanel is a dumb fixed-size transparent container.
private struct FloatingIndicatorView: View {
    @Environment(AudioAmplitudeProvider.self) private var amplitudeProvider
    @Environment(SettingsManager.self) private var settings
    @ObservedObject var stateHolder: StateHolder
    @State private var isHovered = false

    private var isIdle: Bool { stateHolder.currentState == .idle }
    private var isListening: Bool { stateHolder.currentState == .listening }

    private var frameWidth: CGFloat {
        switch stateHolder.currentState {
        case .idle: return 80
        default: return 130
        }
    }

    private var frameHeight: CGFloat {
        switch stateHolder.currentState {
        case .idle: return isHovered ? 8 : 4
        default: return 32
        }
    }

    private var cornerRadius: CGFloat {
        switch stateHolder.currentState {
        case .idle: return isHovered ? 4 : 2
        default: return 10
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.black.opacity(isIdle && isHovered ? 0.95 : 0.92))
                .shadow(color: .black.opacity(isIdle ? 0.3 : 0.5), radius: isIdle ? 4 : 12,
                        x: 0, y: isIdle ? 2 : 4)

            if isListening {
                WaveformBars(
                    amplitudes: amplitudeProvider.amplitudes,
                    startIndex: amplitudeProvider.amplitudesStartIndex,
                    barCount: 28,
                    pixelRows: 7,
                    color: settings.accentColor
                )
                .transition(.opacity)
            } else if !isIdle {
                ClaudePixelSpinner(
                    state: stateHolder.currentState,
                    color: .white,
                    pixelSize: 3,
                    spacing: 1,
                    glowIntensity: 1.2,
                    cols: 28,
                    rows: 3
                )
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .scale(scale: 0.01).combined(with: .opacity)
                ))
            }
        }
        .frame(width: frameWidth, height: frameHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(.white.opacity(isIdle ? (isHovered ? 0.20 : 0.08) : 0.15), lineWidth: 0.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onHover { hovering in
            if isIdle { isHovered = hovering }
        }
        .onTapGesture {
            if isIdle { stateHolder.onTap?() }
        }
        .onChange(of: stateHolder.currentState) { _, newState in
            if newState != .idle { isHovered = false }
        }
        .animation(.spring(duration: 0.35, bounce: 0.15), value: stateHolder.currentState)
        .animation(.spring(duration: 0.25, bounce: 0.2), value: isHovered)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}
