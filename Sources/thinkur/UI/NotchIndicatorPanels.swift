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

    private static let leftWingWidth: CGFloat = 34
    private static let rightWingWidth: CGFloat = 64
    private static let cornerRadius: CGFloat = 8
    private static let notchOverlap: CGFloat = 10

    var isAvailable: Bool { leftPanel != nil }

    init(amplitudeProvider: AudioAmplitudeProvider) {
        self.amplitudeProvider = amplitudeProvider

        guard let hidden = Self.calculateHiddenFrames() else { return }

        leftPanel = Self.makePanel(
            contentRect: hidden.left,
            rootView: NotchLeftWingView(isListening: false)
        )
        rightPanel = Self.makePanel(
            contentRect: hidden.right,
            rootView: NotchRightWingView(isListening: false, amplitudeProvider: amplitudeProvider)
        )
    }

    func show() {
        guard let shown = Self.calculateShownFrames(),
              let hidden = Self.calculateHiddenFrames() else { return }

        leftPanel?.setFrame(hidden.left, display: false)
        rightPanel?.setFrame(hidden.right, display: false)
        leftPanel?.orderFrontRegardless()
        rightPanel?.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            leftPanel?.animator().setFrame(shown.left, display: true)
            rightPanel?.animator().setFrame(shown.right, display: true)
        }
    }

    func hide() {
        guard let hidden = Self.calculateHiddenFrames() else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            leftPanel?.animator().setFrame(hidden.left, display: true)
            rightPanel?.animator().setFrame(hidden.right, display: true)
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                self?.leftPanel?.orderOut(nil)
                self?.rightPanel?.orderOut(nil)
            }
        })
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

    private static func calculateShownFrames() -> (left: NSRect, right: NSRect)? {
        guard let screen = NSScreen.main,
              let leftArea = screen.auxiliaryTopLeftArea,
              let rightArea = screen.auxiliaryTopRightArea else {
            return nil
        }

        let wingHeight = screen.safeAreaInsets.top
        let notchLeftEdge = screen.frame.origin.x + leftArea.width
        let notchRightEdge = screen.frame.maxX - rightArea.width
        let topY = screen.frame.maxY - wingHeight

        let leftRect = NSRect(
            x: notchLeftEdge - leftWingWidth + notchOverlap,
            y: topY,
            width: leftWingWidth,
            height: wingHeight
        )
        let rightRect = NSRect(
            x: notchRightEdge - notchOverlap,
            y: topY,
            width: rightWingWidth,
            height: wingHeight
        )

        return (leftRect, rightRect)
    }

    private static func calculateHiddenFrames() -> (left: NSRect, right: NSRect)? {
        guard let screen = NSScreen.main,
              let leftArea = screen.auxiliaryTopLeftArea,
              let rightArea = screen.auxiliaryTopRightArea else {
            return nil
        }

        let wingHeight = screen.safeAreaInsets.top
        let notchLeftEdge = screen.frame.origin.x + leftArea.width
        let notchRightEdge = screen.frame.maxX - rightArea.width
        let topY = screen.frame.maxY - wingHeight

        let leftRect = NSRect(
            x: notchLeftEdge,
            y: topY,
            width: leftWingWidth,
            height: wingHeight
        )
        let rightRect = NSRect(
            x: notchRightEdge - rightWingWidth,
            y: topY,
            width: rightWingWidth,
            height: wingHeight
        )

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
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.contentView = NSHostingView(rootView: rootView)
        return panel
    }
}

// MARK: - SwiftUI Views

private struct NotchLeftWingView: View {
    let isListening: Bool

    var body: some View {
        UnevenRoundedRectangle(
                bottomLeadingRadius: 8,
                bottomTrailingRadius: 8,
                style: .continuous
            )
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
        UnevenRoundedRectangle(
                bottomLeadingRadius: 8,
                bottomTrailingRadius: 8,
                style: .continuous
            )
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
                            barColor: .white,
                            amplitudeExponent: 0.55
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
