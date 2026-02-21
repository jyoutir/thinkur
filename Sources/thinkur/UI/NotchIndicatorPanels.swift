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

    private let stateHolder = StateHolder()
    private var amplitudeProvider: AudioAmplitudeProvider?

    var isAvailable: Bool { leftPanel != nil }

    init(amplitudeProvider: AudioAmplitudeProvider? = nil, settings: SettingsManager? = nil) {
        self.amplitudeProvider = amplitudeProvider
        stateHolder.currentState = .idle

        guard let frame = Self.calculateFrame(width: Self.idleWingWidth) else { return }

        // Capture weak self for tap — onLeftWingTapped is set after init
        let tapAction: () -> Void = { [weak self] in self?.onLeftWingTapped?() }

        // Create NSHostingView ONCE — state updates flow through StateHolder
        let wingView = NotchLeftWingView(stateHolder: stateHolder, onTap: tapAction)
        if let provider = amplitudeProvider {
            if let settings {
                leftPanel = Self.makePanel(
                    contentRect: frame,
                    rootView: wingView
                        .environment(provider)
                        .environment(settings),
                    ignoresMouseEvents: false
                )
            } else {
                leftPanel = Self.makePanel(
                    contentRect: frame,
                    rootView: wingView
                        .environment(provider),
                    ignoresMouseEvents: false
                )
            }
        } else {
            leftPanel = Self.makePanel(
                contentRect: frame,
                rootView: wingView,
                ignoresMouseEvents: false
            )
        }
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
        // Update state through StateHolder — no NSHostingView recreation
        if stateHolder.currentState != state {
            stateHolder.currentState = state
        }

        // Animate wing width
        let targetWidth: CGFloat = switch state {
        case .idle, .error: Self.idleWingWidth
        default:            Self.expandedWingWidth
        }

        guard let panel = leftPanel,
              let newFrame = Self.calculateFrame(width: targetWidth) else { return }

        if abs(panel.frame.width - targetWidth) < 0.5 {
            return
        }

        panel.orderFrontRegardless()
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

    /// Returns the screen with a notch (built-in display), regardless of which screen is "main".
    private static func notchScreen() -> NSScreen? {
        NSScreen.screens.first { $0.auxiliaryTopLeftArea != nil }
    }

    private static func calculateFrame(width: CGFloat) -> NSRect? {
        guard let screen = notchScreen(),
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
        guard let screen = notchScreen(),
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

    private static func makePanel(
        contentRect: NSRect,
        rootView: some View,
        ignoresMouseEvents: Bool = true
    ) -> NSPanel {
        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: 102)  // Just above popUpMenu (101), helps App Nap
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
    @ObservedObject var stateHolder: StateHolder
    let onTap: () -> Void

    @Environment(AudioAmplitudeProvider.self) private var amplitudeProvider: AudioAmplitudeProvider?
    @Environment(SettingsManager.self) private var settings: SettingsManager?

    private var spinnerColor: Color {
        switch stateHolder.currentState {
        case .listening, .success: return settings?.accentColor ?? AccentColor.defaultGreen.color
        default:                   return .white
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
                    state: stateHolder.currentState,
                    color: spinnerColor,
                    pixelSize: 3,
                    spacing: 1,
                    glowIntensity: 0.6,
                    audioAmplitudes: amplitudeProvider?.amplitudes
                )
                .offset(x: -3, y: 0)
                .opacity(stateHolder.currentState == .idle ? 0 : 1)
                .animation(.easeInOut(duration: 0.25), value: stateHolder.currentState)
            }
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
    }
}
