import Cocoa
import SwiftUI

/// Floating NSPanel that displays the audio waveform at the bottom center of the screen.
/// Uses .nonactivatingPanel so it never steals focus from the app the user is typing in.
final class FloatingIndicatorPanel: NSPanel {
    private let amplitudeProvider: AudioAmplitudeProvider

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

        let waveformView = FloatingWaveformView()
            .environment(amplitudeProvider)

        contentView = NSHostingView(rootView: waveformView)
    }

    func updateAppearance(for themeMode: ThemeMode) {
        self.appearance = NSAppearance(named: themeMode == .dark ? .darkAqua : .aqua)
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

    /// Transition to thinking dots, then fade out after a brief delay.
    func hideWithThinkingTransition() {
        guard let hostingView = contentView as? NSHostingView<FloatingWaveformView> else {
            hide()
            return
        }

        let thinkingView = FloatingThinkingView()
        let thinkingHosting = NSHostingView(rootView: thinkingView)
        thinkingHosting.frame = hostingView.frame
        contentView = thinkingHosting

        // Fade out after a short delay to give the thinking dots a moment on screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                self?.animator().alphaValue = 0
            } completionHandler: { [weak self] in
                self?.orderOut(nil)
                self?.alphaValue = 1
                // Restore the waveform view for next show()
                if let self = self {
                    let waveformView = FloatingWaveformView()
                        .environment(self.amplitudeProvider)
                    self.contentView = NSHostingView(rootView: waveformView)
                }
            }
        }
    }

    func hide() {
        orderOut(nil)
    }
}

private struct FloatingWaveformView: View {
    @Environment(AudioAmplitudeProvider.self) private var amplitudeProvider

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black)

            ClaudePixelSpinner(
                state: .listening,
                color: Color(red: 0.40, green: 0.90, blue: 0.55),  // Green
                pixelSize: 3,
                spacing: 1,
                glowIntensity: 0.6,
                cols: 34,
                rows: 5,
                symmetricWaveform: true,
                audioAmplitudes: amplitudeProvider.amplitudes
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Shows thinking dots in a pixelated style matching the waveform.
private struct FloatingThinkingView: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black)

            ClaudePixelSpinner(
                state: .processing,
                color: .white,
                pixelSize: 3,
                spacing: 1,
                glowIntensity: 0.8,
                cols: 34,
                rows: 5
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
