import SwiftUI

// MARK: - Animation States

enum SpinnerState: String, CaseIterable, Identifiable {
    case idle
    case listening
    case thinking
    case speaking
    case success
    case error
    case connecting
    case processing

    var id: String { rawValue }

    var label: String {
        switch self {
        case .idle:        return "Idle"
        case .listening:   return "Listening"
        case .thinking:    return "Thinking"
        case .speaking:    return "Speaking"
        case .success:     return "Success"
        case .error:       return "Error"
        case .connecting:  return "Connecting"
        case .processing:  return "Processing"
        }
    }

    var cycleDuration: Double {
        switch self {
        case .idle:        return 4.0
        case .listening:   return 1.4
        case .thinking:    return 0.7
        case .speaking:    return 0.5
        case .success:     return 1.8
        case .error:       return 0.6
        case .connecting:  return 1.0
        case .processing:  return 0.45
        }
    }
}

// MARK: - AppState Mapping

extension SpinnerState {
    init(from appState: AppState) {
        switch appState {
        case .idle:          self = .idle
        case .loading:       self = .connecting
        case .listening:     self = .listening
        case .processing:    self = .thinking
        case .error:         self = .error
        }
    }
}

// MARK: - Main View

struct ClaudePixelSpinner: View {

    var state: SpinnerState = .thinking
    var color: Color = Color(red: 0.83, green: 0.55, blue: 0.38)
    var pixelSize: CGFloat = 8
    var spacing: CGFloat = 4
    var glowIntensity: Double = 1.0

    @State private var epochDate = Date()
    @State private var blinkPixel: Int = -1
    @State private var blinkBrightness: Double = 0
    @State private var blinkTimer: Timer?

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(epochDate)
            let phase = fmod(elapsed / state.cycleDuration, 1.0)

            VStack(spacing: spacing) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<3, id: \.self) { col in
                            let index = row * 3 + col
                            PixelDot(
                                color: pixelColor(for: state),
                                brightness: brightness(row: row, col: col, index: index, phase: phase),
                                size: pixelSize,
                                glowIntensity: effectiveGlow(for: state, index: index)
                            )
                        }
                    }
                }
            }
        }
        .onAppear {
            if state == .idle { startBlinkTimer() }
        }
        .onDisappear {
            blinkTimer?.invalidate()
        }
        .onChange(of: state) { _, newState in
            epochDate = Date()
            if newState == .idle {
                startBlinkTimer()
            } else {
                blinkTimer?.invalidate()
                blinkTimer = nil
                blinkPixel = -1
            }
        }
    }

    // MARK: - Brightness Per State

    private func brightness(row: Int, col: Int, index: Int, phase: Double) -> Double {
        switch state {

        // All pixels breathe together barely above darkness.
        // Random lone-pixel "firefly" blinks add life.
        case .idle:
            let breath = 0.12 + 0.06 * sin(phase * 2 * .pi)
            if index == blinkPixel {
                return breath + blinkBrightness
            }
            return breath

        // Equalizer columns — each column oscillates at a different frequency/phase
        // like vertical waveform bars. Bottom row stays bright as the "base".
        case .listening:
            let colPhaseOffset = [0.0, 0.33, 0.15][col]
            let wave = sin((phase + colPhaseOffset) * 2 * .pi)
            // Row 2 (bottom) = base, always fairly bright
            // Row 1 (mid) = follows wave
            // Row 0 (top) = only lights up at peaks
            let rowThreshold: Double = switch row {
            case 2:  0.35 + 0.15 * wave  // base: always visible
            case 1:  max(0.08, 0.5 + 0.5 * wave)  // mid: follows amplitude
            default: max(0.06, wave)  // top: only at peaks
            }
            return rowThreshold

        // Classic left-to-right sine with vertical stagger.
        case .thinking:
            let offset = Double(col) / 3.0 + Double(row) * 0.1
            return 0.5 + 0.5 * sin((phase + offset) * 2 * .pi)

        // Top-to-bottom cascade with column wobble.
        case .speaking:
            let rowDelay = Double(row) * 0.25
            let colWobble = Double(col) * 0.06
            let wave = sin((phase - rowDelay - colWobble) * 2 * .pi)
            return max(0, wave)

        // All 9 bloom bright, hold, fade to afterglow.
        case .success:
            let t = min(phase / 1.0, 1.0)
            if t < 0.15 {
                return easeOut(t / 0.15)
            } else if t < 0.45 {
                return 1.0
            } else {
                let fadeT = (t - 0.45) / 0.55
                return 1.0 - easeIn(fadeT) * 0.7
            }

        // Sharp double-pulse (cardiac skip), then dims.
        case .error:
            let t = fmod(phase, 1.0)
            if t < 0.12 { return easeOut(t / 0.12) }
            if t < 0.20 { return 1.0 - easeIn((t - 0.12) / 0.08) * 0.7 }
            if t < 0.32 { return 0.3 + 0.7 * easeOut((t - 0.2) / 0.12) }
            if t < 0.50 { return 1.0 - easeIn((t - 0.32) / 0.18) * 0.85 }
            return 0.15

        // Clockwise spiral around perimeter, center dim.
        case .connecting:
            let perimOrder = [0, 1, 2, 5, 8, 7, 6, 3]
            if index == 4 {
                return 0.08 + 0.04 * sin(phase * 2 * .pi)
            }
            guard let pi = perimOrder.firstIndex(of: index) else { return 0 }
            let pixelPhase = Double(pi) / Double(perimOrder.count)
            let diff = fmod(phase - pixelPhase + 1.0, 1.0)
            let spread = 0.15
            return exp(-pow(min(diff, 1.0 - diff) / spread, 2))

        // Dual diagonal interference with golden ratio offset.
        case .processing:
            let diag1 = Double(row + col) / 4.0
            let diag2 = Double(row - col + 2) / 4.0
            let wave1 = sin((phase + diag1) * 2 * .pi)
            let wave2 = sin((phase * 1.618 + diag2) * 2 * .pi)
            return 0.5 + 0.5 * (wave1 + wave2) / 2.0
        }
    }

    // MARK: - Per-State Color

    private func pixelColor(for state: SpinnerState) -> Color {
        switch state {
        case .success: return Color(red: 0.40, green: 0.90, blue: 0.55)
        case .error:   return Color(red: 0.90, green: 0.40, blue: 0.40)
        default:       return color
        }
    }

    // MARK: - Per-State Glow

    private func effectiveGlow(for state: SpinnerState, index: Int) -> Double {
        switch state {
        case .idle:
            return index == blinkPixel ? glowIntensity * 1.5 : glowIntensity * 0.3
        case .success:    return glowIntensity * 1.8
        case .error:      return glowIntensity * 1.4
        case .connecting: return index == 4 ? glowIntensity * 0.2 : glowIntensity * 1.2
        case .processing: return glowIntensity * 1.3
        default:          return glowIntensity
        }
    }

    // MARK: - Idle Blink

    private func startBlinkTimer() {
        blinkTimer?.invalidate()
        scheduleBlink()
    }

    private func scheduleBlink() {
        let delay = Double.random(in: 1.5...4.0)
        blinkTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            triggerBlink()
        }
    }

    private func triggerBlink() {
        blinkPixel = Int.random(in: 0..<9)
        withAnimation(.easeOut(duration: 0.2)) { blinkBrightness = 0.7 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeIn(duration: 0.6)) { blinkBrightness = 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            blinkPixel = -1
            if state == .idle { scheduleBlink() }
        }
    }

    // MARK: - Easing

    private func easeOut(_ t: Double) -> Double { 1 - pow(1 - t, 3) }
    private func easeIn(_ t: Double) -> Double { t * t * t }
}

// MARK: - Pixel Dot

private struct PixelDot: View {
    let color: Color
    let brightness: Double
    let size: CGFloat
    let glowIntensity: Double

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.15)
            .fill(color)
            .frame(width: size, height: size)
            .opacity(brightness)
            .shadow(color: color.opacity(0.20 * glowIntensity * brightness), radius: 1 * glowIntensity)
            .shadow(color: color.opacity(0.14 * glowIntensity * brightness), radius: 3 * glowIntensity)
            .shadow(color: color.opacity(0.11 * glowIntensity * brightness), radius: 6 * glowIntensity)
            .shadow(color: color.opacity(0.06 * glowIntensity * brightness), radius: 10 * glowIntensity)
            .shadow(color: color.opacity(0.03 * glowIntensity * brightness), radius: 16 * glowIntensity)
    }
}

// MARK: - Color Presets

extension ClaudePixelSpinner {
    static func claude(_ s: SpinnerState = .thinking) -> ClaudePixelSpinner { .init(state: s) }
    static func ocean(_ s: SpinnerState = .thinking) -> ClaudePixelSpinner { .init(state: s, color: Color(red: 0.39, green: 0.78, blue: 1.0)) }
    static func gold(_ s: SpinnerState = .thinking) -> ClaudePixelSpinner { .init(state: s, color: Color(red: 0.91, green: 0.69, blue: 0.47)) }
    static func mint(_ s: SpinnerState = .thinking) -> ClaudePixelSpinner { .init(state: s, color: Color(red: 0.63, green: 0.92, blue: 0.71)) }
    static func coral(_ s: SpinnerState = .thinking) -> ClaudePixelSpinner { .init(state: s, color: Color(red: 0.96, green: 0.51, blue: 0.51)) }
    static func ice(_ s: SpinnerState = .thinking) -> ClaudePixelSpinner { .init(state: s, color: .white, glowIntensity: 0.6) }
}

// MARK: - Overlay Modifier

extension View {
    func pixelSpinnerOverlay(
        state: SpinnerState = .thinking,
        isVisible: Bool,
        color: Color = Color(red: 0.83, green: 0.55, blue: 0.38),
        label: String? = nil
    ) -> some View {
        self.overlay {
            if isVisible {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    VStack(spacing: 14) {
                        ClaudePixelSpinner(state: state, color: color)
                        if let label {
                            Text(label)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(color.opacity(0.7))
                        }
                    }
                }
                .transition(.opacity.animation(.easeInOut(duration: 0.25)))
            }
        }
    }
}
