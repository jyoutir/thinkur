import Cocoa
import SwiftUI

/// Two NSPanels that visually extend from the notch as black wings with rounded bottom corners.
/// Left wing: app logo. Right wing: waveform (listening) or static bars (idle).
/// Always visible once shown — `setListening(_:)` toggles between active/idle appearance.
@MainActor
final class NotchIndicatorPanels {
    private var leftPanel: NSPanel?
    private var rightPanel: NSPanel?
    private let amplitudeProvider: AudioAmplitudeProvider

    private static let wingHeight: CGFloat = 34
    private static let leftWingWidth: CGFloat = 34
    private static let rightWingWidth: CGFloat = 64
    private static let cornerRadius: CGFloat = 8
    private static let notchHalfWidth: CGFloat = 97

    init(amplitudeProvider: AudioAmplitudeProvider) {
        self.amplitudeProvider = amplitudeProvider

        let (leftRect, rightRect) = Self.calculateFrames()

        leftPanel = Self.makePanel(
            contentRect: leftRect,
            rootView: NotchLeftWingView(isListening: false)
        )
        rightPanel = Self.makePanel(
            contentRect: rightRect,
            rootView: NotchRightWingView(isListening: false, amplitudeProvider: amplitudeProvider)
        )
    }

    func show() {
        let (leftRect, rightRect) = Self.calculateFrames()
        leftPanel?.setFrame(leftRect, display: true)
        rightPanel?.setFrame(rightRect, display: true)
        leftPanel?.orderFrontRegardless()
        rightPanel?.orderFrontRegardless()
    }

    func hide() {
        leftPanel?.orderOut(nil)
        rightPanel?.orderOut(nil)
    }

    func setListening(_ listening: Bool) {
        leftPanel?.contentView = NSHostingView(
            rootView: NotchLeftWingView(isListening: listening)
        )
        rightPanel?.contentView = NSHostingView(
            rootView: NotchRightWingView(isListening: listening, amplitudeProvider: amplitudeProvider)
        )
    }

    func updateAppearance() {
        // Wings are always dark — no theme switching needed
    }

    // MARK: - Geometry

    private static func calculateFrames() -> (left: NSRect, right: NSRect) {
        guard let screen = NSScreen.main else {
            return (.zero, .zero)
        }

        let screenFrame = screen.frame
        let centerX = screenFrame.midX

        // Top edge flush with screen top; wing hangs down from top
        let topY = screenFrame.maxY - wingHeight

        let leftX = centerX - notchHalfWidth - leftWingWidth
        let rightX = centerX + notchHalfWidth

        let leftRect = NSRect(x: leftX, y: topY, width: leftWingWidth, height: wingHeight)
        let rightRect = NSRect(x: rightX, y: topY, width: rightWingWidth, height: wingHeight)

        return (leftRect, rightRect)
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
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.contentView = NSHostingView(rootView: rootView)
        return panel
    }
}

// MARK: - SwiftUI Views

private struct NotchLeftWingView: View {
    let isListening: Bool

    var body: some View {
        UnevenRoundedRectangle(bottomLeadingRadius: 8)
            .fill(.black)
            .overlay {
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isListening ? .white : .red)
                    .offset(y: 4)
            }
    }
}

private struct NotchRightWingView: View {
    let isListening: Bool
    let amplitudeProvider: AudioAmplitudeProvider

    var body: some View {
        UnevenRoundedRectangle(bottomTrailingRadius: 8)
            .fill(.black)
            .overlay {
                Group {
                    if isListening {
                        LiveAudioWaveform(
                            amplitudes: amplitudeProvider.amplitudes,
                            barCount: 5,
                            height: 18,
                            showGlass: false,
                            horizontalPadding: 4,
                            barColor: .white
                        )
                    } else {
                        IdleNotchBars()
                    }
                }
                .offset(y: 4)
            }
    }
}

private struct IdleNotchBars: View {
    var body: some View {
        HStack(spacing: LiveAudioWaveform.barGap) {
            ForEach(0..<5, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.red)
                    .frame(width: LiveAudioWaveform.barWidth, height: 6)
            }
        }
    }
}
