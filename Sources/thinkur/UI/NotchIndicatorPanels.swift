import Cocoa
import SwiftUI

/// Single NSPanel that visually extends from the notch as a black wing with rounded bottom corners.
/// The wing expands from compact (3×3 idle) to full width (3×6 listening/processing).
/// Clickable to toggle listening.
@MainActor
final class NotchIndicatorPanels {
    private var leftPanel: NSPanel?
    var onLeftWingTapped: (() -> Void)?

    private static let idleWingWidth: CGFloat = 26
    private static let expandedWingWidth: CGFloat = 42
    private static let notchOverlap: CGFloat = 10

    private var currentState: SpinnerState = .idle

    var isAvailable: Bool { leftPanel != nil }

    init() {
        guard let frame = Self.calculateFrame(width: Self.idleWingWidth) else { return }

        leftPanel = Self.makePanel(
            contentRect: frame,
            rootView: NotchLeftWingView(state: .idle, onTap: { }),
            ignoresMouseEvents: false
        )
    }

    /// Show the left wing permanently. Call once at app startup.
    func showLeftWing() {
        guard let hiddenFrame = Self.calculateHiddenFrame(width: Self.idleWingWidth),
              let shownFrame = Self.calculateFrame(width: Self.idleWingWidth) else { return }

        leftPanel?.setFrame(hiddenFrame, display: false)
        leftPanel?.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            leftPanel?.animator().setFrame(shownFrame, display: true)
        }
    }

    func setState(_ state: SpinnerState) {
        currentState = state

        // Update SwiftUI content
        // NSPanel automatically manages view lifecycle when setting contentView
        let tapAction: () -> Void = { [weak self] in self?.onLeftWingTapped?() }
        leftPanel?.contentView = NSHostingView(
            rootView: NotchLeftWingView(state: state, onTap: tapAction)
        )

        // Animate wing width
        let targetWidth: CGFloat = switch state {
        case .idle, .error: Self.idleWingWidth
        default:            Self.expandedWingWidth
        }

        guard let newFrame = Self.calculateFrame(width: targetWidth) else { return }

        leftPanel?.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { [weak self] context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self?.leftPanel?.animator().setFrame(newFrame, display: true)
        }
    }

    func updateAppearance() {
        // Wings are always dark — no theme switching needed
    }

    // MARK: - Geometry

    private static func calculateFrame(width: CGFloat) -> NSRect? {
        guard let screen = NSScreen.main,
              let leftArea = screen.auxiliaryTopLeftArea else { return nil }

        let wingHeight = screen.safeAreaInsets.top
        let notchLeftEdge = screen.frame.origin.x + leftArea.width
        let topY = screen.frame.maxY - wingHeight

        return NSRect(
            x: notchLeftEdge - width + notchOverlap,
            y: topY,
            width: width,
            height: wingHeight
        )
    }

    private static func calculateHiddenFrame(width: CGFloat) -> NSRect? {
        guard let screen = NSScreen.main,
              let leftArea = screen.auxiliaryTopLeftArea else { return nil }

        let wingHeight = screen.safeAreaInsets.top
        let notchLeftEdge = screen.frame.origin.x + leftArea.width
        let topY = screen.frame.maxY - wingHeight

        return NSRect(
            x: notchLeftEdge,
            y: topY,
            width: width,
            height: wingHeight
        )
    }

    // MARK: - Panel Factory

    private static func makePanel<V: View>(
        contentRect: NSRect,
        rootView: V,
        ignoresMouseEvents: Bool = true
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
        panel.ignoresMouseEvents = ignoresMouseEvents
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.contentView = NSHostingView(rootView: rootView)
        return panel
    }
}

// MARK: - SwiftUI Views

private struct NotchLeftWingView: View {
    let state: SpinnerState
    let onTap: () -> Void

    private var spinnerColor: Color {
        switch state {
        case .listening: return Color(red: 0.40, green: 0.90, blue: 0.55)
        default:         return .white
        }
    }

    var body: some View {
        UnevenRoundedRectangle(
                bottomLeadingRadius: 8,
                bottomTrailingRadius: 8,
                style: .continuous
            )
            .fill(.black)
            .overlay {
                ClaudePixelSpinner(
                    state: state,
                    color: spinnerColor,
                    pixelSize: 3,
                    spacing: 1,
                    glowIntensity: 0.6
                )
                .offset(y: -4)
            }
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
    }
}
