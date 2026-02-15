import Cocoa
import SwiftUI

/// Floating NSPanel that displays the audio waveform at the bottom center of the screen.
/// Uses .nonactivatingPanel so it never steals focus from the app the user is typing in.
final class FloatingIndicatorPanel: NSPanel {
    private let amplitudeProvider: AudioAmplitudeProvider

    init(amplitudeProvider: AudioAmplitudeProvider) {
        self.amplitudeProvider = amplitudeProvider

        let panelWidth: CGFloat = 200
        let panelHeight: CGFloat = 60

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

        let waveformView = FloatingWaveformView()
            .environment(amplitudeProvider)

        contentView = NSHostingView(rootView: waveformView)
    }

    func show() {
        orderFrontRegardless()
    }

    func hide() {
        orderOut(nil)
    }
}

private struct FloatingWaveformView: View {
    @Environment(AudioAmplitudeProvider.self) private var amplitudeProvider

    var body: some View {
        GeometryReader { geo in
            let bars = LiveAudioWaveform.calculateMaxBars(availableWidth: geo.size.width)
            LiveAudioWaveform(
                amplitudes: amplitudeProvider.amplitudes,
                barCount: bars,
                height: geo.size.height
            )
        }
    }
}
