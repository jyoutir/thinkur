import Cocoa
import SwiftUI

/// Two small NSPanels that flank the notch (or screen center) in the menu bar strip,
/// showing a logo on the left and a mini waveform on the right during recording.
@MainActor
final class NotchIndicatorPanels {
    private var leftPanel: NSPanel?
    private var rightPanel: NSPanel?
    private let amplitudeProvider: AudioAmplitudeProvider

    private static let logoSize = NSSize(width: 30, height: 24)
    private static let waveformSize = NSSize(width: 60, height: 24)

    init(amplitudeProvider: AudioAmplitudeProvider) {
        self.amplitudeProvider = amplitudeProvider

        let (leftOrigin, rightOrigin) = Self.calculatePositions()

        leftPanel = Self.makePanel(
            contentRect: NSRect(origin: leftOrigin, size: Self.logoSize),
            rootView: NotchLogoView()
        )

        rightPanel = Self.makePanel(
            contentRect: NSRect(origin: rightOrigin, size: Self.waveformSize),
            rootView: NotchWaveformView().environment(amplitudeProvider)
        )
    }

    func show() {
        let (leftOrigin, rightOrigin) = Self.calculatePositions()
        leftPanel?.setFrameOrigin(leftOrigin)
        rightPanel?.setFrameOrigin(rightOrigin)
        leftPanel?.orderFrontRegardless()
        rightPanel?.orderFrontRegardless()
    }

    func hide() {
        leftPanel?.orderOut(nil)
        rightPanel?.orderOut(nil)
    }

    func updateAppearance() {
        // Notch panels are always dark: black background with white content
    }

    // MARK: - Geometry

    private static func calculatePositions() -> (left: NSPoint, right: NSPoint) {
        guard let screen = NSScreen.main else {
            return (.zero, .zero)
        }

        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        let menuBarHeight = screenFrame.maxY - visibleFrame.maxY

        // Notch Macs have ~37pt menu bar; non-notch ~25pt
        let hasNotch = menuBarHeight > 30
        let halfGap: CGFloat = hasNotch ? 97 : 10

        let centerX = screenFrame.midX
        let menuBarY = visibleFrame.maxY  // bottom of menu bar strip

        // Vertically center panels within the menu bar strip
        let leftY = menuBarY + (menuBarHeight - logoSize.height) / 2
        let rightY = menuBarY + (menuBarHeight - waveformSize.height) / 2

        let leftOrigin = NSPoint(x: centerX - halfGap - logoSize.width, y: leftY)
        let rightOrigin = NSPoint(x: centerX + halfGap, y: rightY)

        return (leftOrigin, rightOrigin)
    }

    // MARK: - Panel Factory

    private static func makePanel<V: View>(
        contentRect: NSRect,
        rootView: V
    ) -> NSPanel {
        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .black
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Always dark so .primary resolves to white
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.contentView = NSHostingView(rootView: rootView)
        return panel
    }
}

// MARK: - SwiftUI Views

private struct NotchLogoView: View {
    var body: some View {
        Image(systemName: "waveform")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NotchWaveformView: View {
    @Environment(AudioAmplitudeProvider.self) private var amplitudeProvider

    var body: some View {
        LiveAudioWaveform(
            amplitudes: amplitudeProvider.amplitudes,
            barCount: 5,
            height: 18,
            showGlass: false,
            horizontalPadding: 4
        )
    }
}
