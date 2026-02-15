import SwiftUI

enum Animations {
    static let pageTransition = Animation.easeInOut(duration: 0.35)
    static let springBounce = Animation.spring(duration: 0.35, bounce: 0.3)
    static let waveformTick = Animation.easeOut(duration: 0.08)
    static let hoverFade = Animation.easeInOut(duration: 0.15)
    static let onboardingEntrance = Animation.spring(duration: 0.4, bounce: 0.2)
}
