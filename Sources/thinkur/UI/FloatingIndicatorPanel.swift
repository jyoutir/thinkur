import Cocoa
import SwiftUI

/// Floating NSPanel that displays the indicator at the bottom center of the screen.
/// Uses .nonactivatingPanel so it never steals focus from the app the user is typing in.
///
/// The panel is a fixed 160×50 transparent container — all visual sizing and animation
/// is handled by SwiftUI inside FloatingIndicatorView.
final class FloatingIndicatorPanel: NSPanel {
    private let amplitudeProvider: AudioAmplitudeProvider
    private let stateHolder = StateHolder()
    private var screenObserver: NSObjectProtocol?

    /// Fixed panel size — large enough to contain the biggest state (listening: 139×24)
    private static let fixedSize = NSSize(width: 160, height: 50)

    init(amplitudeProvider: AudioAmplitudeProvider, themeMode: ThemeMode = .dark) {
        self.amplitudeProvider = amplitudeProvider

        let size = Self.fixedSize

        // Position at bottom center of built-in screen (prefer notch screen over main)
        let screenFrame = (NSScreen.screens.first { $0.auxiliaryTopLeftArea != nil } ?? NSScreen.main)?.visibleFrame ?? .zero
        let originX = screenFrame.midX - size.width / 2
        let originY = screenFrame.minY + 6

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
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
        self.appearance = NSAppearance(named: themeMode == .dark ? .darkAqua : .aqua)

        let indicatorView = FloatingIndicatorView(stateHolder: stateHolder)
            .environment(amplitudeProvider)

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
        stateHolder.currentState = state
    }

    func show() {
        recenter()
        orderFrontRegardless()
    }

    private func recenter() {
        let size = Self.fixedSize
        let screenFrame = (NSScreen.screens.first { $0.auxiliaryTopLeftArea != nil } ?? NSScreen.main)?.visibleFrame ?? .zero
        let originX = screenFrame.midX - size.width / 2
        let originY = screenFrame.minY + 6
        setFrame(NSRect(x: originX, y: originY, width: size.width, height: size.height), display: true)
    }
}

// MARK: - State Holder

@MainActor
final class StateHolder: ObservableObject {
    @Published var currentState: SpinnerState = .idle
}

// MARK: - Unified Indicator View

/// All visual sizing and animation is handled here via SwiftUI.
/// The NSPanel is a dumb fixed-size transparent container.
private struct FloatingIndicatorView: View {
    @Environment(AudioAmplitudeProvider.self) private var amplitudeProvider
    @ObservedObject var stateHolder: StateHolder

    private var isIdle: Bool { stateHolder.currentState == .idle }
    private var isListening: Bool { stateHolder.currentState == .listening }

    private var frameWidth: CGFloat {
        switch stateHolder.currentState {
        case .idle: return 80
        default: return 50
        }
    }

    private var frameHeight: CGFloat {
        switch stateHolder.currentState {
        case .idle: return 4
        default: return 24
        }
    }

    private var cornerRadius: CGFloat {
        switch stateHolder.currentState {
        case .idle: return 2
        default: return 8
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.black.opacity(0.92))
                .shadow(color: .black.opacity(isIdle ? 0.3 : 0.5), radius: isIdle ? 4 : 12,
                        x: 0, y: isIdle ? 2 : 4)

            if isListening {
                WaveformBars(
                    amplitudes: amplitudeProvider.amplitudes,
                    startIndex: amplitudeProvider.amplitudesStartIndex,
                    barCount: 7,
                    color: Color(red: 0.15, green: 1.0, blue: 0.35)
                )
            } else if !isIdle {
                ClaudePixelSpinner(
                    state: stateHolder.currentState,
                    color: .white,
                    pixelSize: 3,
                    spacing: 1,
                    glowIntensity: 1.2,
                    cols: 6,
                    rows: 3
                )
            }
        }
        .frame(width: frameWidth, height: frameHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(.white.opacity(isIdle ? 0.08 : 0.15), lineWidth: 0.5)
        )
        .animation(.spring(duration: 0.35, bounce: 0.15), value: stateHolder.currentState)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}
