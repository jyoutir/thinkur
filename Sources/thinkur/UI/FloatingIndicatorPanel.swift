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
        let panelHeight: CGFloat = 50  // Increased for taller 6pt pixels (was 40)

        // Position at bottom center of built-in screen (prefer notch screen over main)
        let screenFrame = (NSScreen.screens.first { $0.auxiliaryTopLeftArea != nil } ?? NSScreen.main)?.visibleFrame ?? .zero
        let originX = screenFrame.midX - panelWidth / 2
        let originY = screenFrame.minY + 45  // 45pt from bottom (adjusted for taller panel)

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
        let screenFrame = (NSScreen.screens.first { $0.auxiliaryTopLeftArea != nil } ?? NSScreen.main)?.visibleFrame ?? .zero
        let panelWidth = frame.width
        let originX = screenFrame.midX - panelWidth / 2
        let originY = screenFrame.minY + 45  // Adjusted for taller panel
        setFrameOrigin(NSPoint(x: originX, y: originY))
    }

    /// Transition to processing (white spinning), then settle back to idle.
    func hideWithThinkingTransition() {
        setState(.processing)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.setState(.idle)
        }
    }
}

// MARK: - State Holder

@MainActor
final class StateHolder: ObservableObject {
    @Published var currentState: SpinnerState = .idle
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

            // Canvas waveform for listening (high perf), pixel spinner for idle/processing
            Group {
                if stateHolder.currentState == .listening {
                    CanvasWaveform(
                        audioAmplitudes: amplitudeProvider.amplitudes,
                        amplitudesStartIndex: amplitudeProvider.amplitudesStartIndex,
                        color: spinnerColor,
                        glowIntensity: glowIntensity,
                        cols: 34,
                        rows: 5,
                        pixelSize: 6,
                        spacing: 1
                    )
                } else {
                    ClaudePixelSpinner(
                        state: stateHolder.currentState,
                        color: spinnerColor,
                        pixelSize: 6,
                        spacing: 1,
                        glowIntensity: glowIntensity,
                        cols: 34,
                        rows: 5,
                        symmetricWaveform: true,
                        fullWidthIdle: true,
                        audioAmplitudes: nil,
                        amplitudesStartIndex: 0
                    )
                }
            }
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
