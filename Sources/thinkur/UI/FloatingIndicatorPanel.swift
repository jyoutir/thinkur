import Cocoa
import SwiftUI

/// Floating NSPanel that displays the audio waveform at the bottom center of the screen.
/// Uses .nonactivatingPanel so it never steals focus from the app the user is typing in.
final class FloatingIndicatorPanel: NSPanel {
    private let amplitudeProvider: AudioAmplitudeProvider
    private let stateHolder = StateHolder()

    init(amplitudeProvider: AudioAmplitudeProvider, themeMode: ThemeMode = .dark) {
        self.amplitudeProvider = amplitudeProvider

        let panelWidth: CGFloat = 160
        let panelHeight: CGFloat = 40

        // Position at bottom center of main screen
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let originX = screenFrame.midX - panelWidth / 2
        let originY = screenFrame.minY + 40  // 40pt from bottom

        super.init(
            contentRect: NSRect(x: originX, y: originY, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true  // Click-through
        hidesOnDeactivate = false  // Stay visible for LSUIElement apps
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
        self.appearance = NSAppearance(named: themeMode == .dark ? .darkAqua : .aqua)

        // Create unified view that handles all states
        let indicatorView = FloatingIndicatorView(stateHolder: stateHolder)
            .environment(amplitudeProvider)

        contentView = NSHostingView(rootView: indicatorView)
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
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let panelWidth = frame.width
        let originX = screenFrame.midX - panelWidth / 2
        let originY = screenFrame.minY + 40
        setFrameOrigin(NSPoint(x: originX, y: originY))
    }

    /// Transition to processing (white spinning), then fade out after a brief delay.
    func hideWithThinkingTransition() {
        // Set processing state (white spinning)
        setState(.processing)

        // Fade out after a short delay to give the processing animation a moment on screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                self?.animator().alphaValue = 0
            } completionHandler: { [weak self] in
                self?.orderOut(nil)
                self?.alphaValue = 1
                // Reset to listening state for next show()
                self?.setState(.listening)
            }
        }
    }

    func hide() {
        orderOut(nil)
    }
}

// MARK: - State Holder

@MainActor
final class StateHolder: ObservableObject {
    @Published var currentState: SpinnerState = .listening
}

// MARK: - Unified Indicator View

/// Unified view that displays both listening (green waveform) and processing (white spinner) states
/// Eliminates NSHostingView recreation for better performance
private struct FloatingIndicatorView: View {
    @Environment(AudioAmplitudeProvider.self) private var amplitudeProvider
    @ObservedObject var stateHolder: StateHolder

    var body: some View {
        ZStack {
            // Dark liquid glass container - rich black with subtle glass effect
            RoundedRectangle(cornerRadius: 12)
                .fill(.black.opacity(0.92))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial.opacity(0.4))
                )
                .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 4)

            ClaudePixelSpinner(
                state: stateHolder.currentState,
                color: spinnerColor,
                pixelSize: 3,
                spacing: 1,
                glowIntensity: glowIntensity,
                cols: 34,
                rows: 5,
                symmetricWaveform: stateHolder.currentState == .listening,
                audioAmplitudes: stateHolder.currentState == .listening ? amplitudeProvider.amplitudes : nil,
                amplitudesStartIndex: amplitudeProvider.amplitudesStartIndex
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        )
    }

    private var spinnerColor: Color {
        switch stateHolder.currentState {
        case .listening:
            // Ultra-vivid electric neon green
            return Color(red: 0.15, green: 1.0, blue: 0.35)
        default:
            return .white
        }
    }

    private var glowIntensity: Double {
        switch stateHolder.currentState {
        case .listening:
            return 1.5  // Increased from 0.6 for much brighter glow
        case .processing:
            return 1.2  // Increased from 0.8 for brighter white glow
        default:
            return 0.8
        }
    }
}
