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
        case .processing:  return 0.35
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
        case .processing:    self = .processing
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
    var cols: Int = 6
    var rows: Int = 3
    var symmetricWaveform: Bool = false
    var audioAmplitudes: [Double]? = nil
    var amplitudesStartIndex: Int = 0

    @State private var epochDate = Date()
    @State private var blinkPixel: Int = -1
    @State private var blinkBrightness: Double = 0
    @State private var blinkTimer: Timer?

    // MARK: - Performance Optimization: Amplitude Curve Cache

    /// Precomputed amplitude curve lookup table to avoid 20k+ pow() calls per second
    /// Uses 0.4 exponent for better sensitivity with quiet sounds (whispers)
    private static let amplitudeCurveCache: [Double] = {
        (0...100).map { i in
            let normalized = Double(i) / 100.0
            return pow(normalized, 0.4)  // 0.4 for better low-volume sensitivity
        }
    }()

    // MARK: - Expansion Mechanic

    private var visibleCols: Int {
        switch state {
        case .idle, .error: return 3
        default:            return cols
        }
    }

    private var colStart: Int { (cols - visibleCols) / 2 }
    private var colEnd: Int { colStart + visibleCols }

    private func isColumnVisible(_ col: Int) -> Bool {
        col >= colStart && col < colEnd
    }

    /// Tapered visibility logic for 5-row symmetric waveform to create rounder shape
    /// - Center row (2): all 34 columns visible
    /// - Adjacent rows (1, 3): trim 1 from each end → 32 columns
    /// - Edge rows (0, 4): trim 2 from each end → 30 columns
    private func isPixelVisible(_ col: Int, _ row: Int) -> Bool {
        guard symmetricWaveform && rows == 5 else {
            return isColumnVisible(col)
        }

        let centerRow = 2
        let distance = abs(row - centerRow)

        // Center row: all columns visible
        if distance == 0 { return col >= 0 && col < cols }

        // Adjacent rows (distance 1): trim 1 from each end
        if distance == 1 { return col >= 1 && col < cols - 1 }

        // Edge rows (distance 2): trim 2 from each end
        return col >= 2 && col < cols - 2
    }

    // Dynamic frame rate based on state for better performance
    private var updateInterval: Double {
        switch state {
        case .idle: return 1.0 / 8.0      // 8fps - slow breathing
        case .listening: return 1.0 / 30.0 // 30fps - smooth audio reactivity
        case .processing: return 1.0 / 20.0 // 20fps - spinning is smooth enough
        default: return 1.0 / 30.0
        }
    }

    var body: some View {
        Group {
            if state == .idle {
                idleContent
            } else {
                activeContent
            }
        }
        .animation(.spring(duration: 0.3, bounce: 0.15), value: state)
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

    // MARK: - Idle Content (Static — no TimelineView, no display link wakes)

    private var idleContent: some View {
        VStack(spacing: spacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<cols, id: \.self) { col in
                        let index = row * cols + col
                        let visible = isPixelVisible(col, row)
                        let isBlinking = index == blinkPixel
                        PixelDot(
                            color: pixelColor(for: .idle),
                            brightness: visible ? (isBlinking ? 0.15 + blinkBrightness : 0.15) : 0,
                            size: pixelSize,
                            glowIntensity: visible ? (isBlinking ? glowIntensity * 1.5 : glowIntensity * 0.3) : 0,
                            shadowsEnabled: true
                        )
                        .frame(width: visible ? pixelSize : 0)
                        .opacity(visible ? 1 : 0)
                        .clipped()
                    }
                }
            }
        }
    }

    // MARK: - Active Content (TimelineView — animated states only)

    private var activeContent: some View {
        TimelineView(.periodic(from: .now, by: updateInterval)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(epochDate)
            let phase = fmod(elapsed / state.cycleDuration, 1.0)
            let perimOrder = perimeterOrder()
            let interiorSet = interiorIndices()
            let shadowsEnabled = state != .listening

            VStack(spacing: spacing) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<cols, id: \.self) { col in
                            let index = row * cols + col
                            let visible = isPixelVisible(col, row)
                            PixelDot(
                                color: pixelColor(for: state),
                                brightness: visible ? brightness(row: row, col: col, index: index, phase: phase, perimeterOrder: perimOrder, interiorIndices: interiorSet) : 0,
                                size: pixelSize,
                                glowIntensity: visible ? effectiveGlow(for: state, index: index, interiorIndices: interiorSet) : 0,
                                shadowsEnabled: shadowsEnabled
                            )
                            .frame(width: visible ? pixelSize : 0)
                            .opacity(visible ? 1 : 0)
                            .clipped()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Brightness Per State

    private func brightness(row: Int, col: Int, index: Int, phase: Double, perimeterOrder: [Int], interiorIndices: Set<Int>) -> Double {
        switch state {

        // Playful breathing + faster firefly twinkle (3×3 compact)
        case .idle:
            let breath = 0.15 + 0.07 * sin(phase * 2 * .pi)
            if index == blinkPixel {
                return breath + blinkBrightness
            }
            return breath

        // Column equalizer waveform (expanded 3×6, green)
        // If we have audio amplitudes, use them for a live reactive waveform
        case .listening:
            if let amplitudes = audioAmplitudes, !amplitudes.isEmpty {
                // Map each column to a recent amplitude sample (right-to-left, newest on right)
                // Support circular buffer reading for memory efficiency
                let offset = amplitudes.count >= cols ? (amplitudes.count - cols + col) : col
                let sampleIndex = (amplitudesStartIndex + offset) % amplitudes.count
                let amplitude = amplitudes[sampleIndex]

                // Use precomputed curve cache instead of pow() for 100% performance gain
                let curveIndex = min(Int(amplitude * 100), 100)
                let curved = Self.amplitudeCurveCache[curveIndex]

                // Symmetric waveform mode: center row is anchor, grows up/down symmetrically
                if symmetricWaveform && rows == 5 {
                    let centerRow = 2
                    let distance = abs(row - centerRow)

                    // Map amplitude to brightness for this entire column (coherent vertical color)
                    // Low amplitude: 0.4 (visible dark green baseline)
                    // High amplitude: 1.0 (vivid bright green)
                    let columnBrightness = 0.4 + (curved * 0.6)  // Maps 0.0-1.0 → 0.4-1.0

                    if row == centerRow {
                        // Center row: always visible, matches column brightness
                        return max(0.4, columnBrightness)
                    }

                    // Outer rows: only light up if amplitude exceeds threshold
                    let threshold: Double = distance == 1 ? 0.10 : 0.25

                    if curved < threshold {
                        // Below threshold: off/very dim
                        return 0.0
                    } else {
                        // Above threshold: match center row brightness for coherent column color
                        return columnBrightness
                    }
                } else {
                    // Original notch behavior: bottom row (2) easiest to light, top row (0) hardest
                    // This creates a "growing bar" effect where higher amplitude lights more rows
                    let rowThreshold: Double = switch row {
                    case 2:  0.08  // Bottom row - always on with slight activity
                    case 1:  0.25  // Middle row - lights up with moderate input
                    default: 0.50  // Top row - only lights up with strong input
                    }

                    // Pixel brightness based on whether amplitude exceeds row threshold
                    let brightness = curved > rowThreshold ? (curved - rowThreshold) / (1.0 - rowThreshold) : 0.1
                    return max(0.06, brightness)
                }
            } else {
                // Fallback: original sine wave animation when no audio data
                let colPhaseOffset = Double(col) * 0.15
                let wave = sin((phase + colPhaseOffset) * 2 * .pi)
                let rowThreshold: Double = switch row {
                case 2:  0.35 + 0.15 * wave
                case 1:  max(0.08, 0.5 + 0.5 * wave)
                default: max(0.06, wave)
                }
                return rowThreshold
            }

        // Classic left-to-right sine with vertical stagger
        case .thinking:
            let offset = Double(col) / Double(cols) + Double(row) * 0.1
            return 0.5 + 0.5 * sin((phase + offset) * 2 * .pi)

        // Top-to-bottom cascade with column wobble
        case .speaking:
            let rowDelay = Double(row) * 0.25
            let colWobble = Double(col) * 0.06
            let wave = sin((phase - rowDelay - colWobble) * 2 * .pi)
            return max(0, wave)

        // All pixels bloom bright, hold, fade to afterglow
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

        // Sharp double-pulse (cardiac skip), then dims
        case .error:
            let t = fmod(phase, 1.0)
            if t < 0.12 { return easeOut(t / 0.12) }
            if t < 0.20 { return 1.0 - easeIn((t - 0.12) / 0.08) * 0.7 }
            if t < 0.32 { return 0.3 + 0.7 * easeOut((t - 0.2) / 0.12) }
            if t < 0.50 { return 1.0 - easeIn((t - 0.32) / 0.18) * 0.85 }
            return 0.15

        // Clockwise spiral around perimeter, center dim
        case .connecting:
            if interiorIndices.contains(index) {
                return 0.08 + 0.04 * sin(phase * 2 * .pi)
            }
            guard let pi = perimeterOrder.firstIndex(of: index) else { return 0 }
            let pixelPhase = Double(pi) / Double(perimeterOrder.count)
            let diff = fmod(phase - pixelPhase + 1.0, 1.0)
            let spread = 0.15
            return exp(-pow(min(diff, 1.0 - diff) / spread, 2))

        // Fast clockwise perimeter loop (expanded 3×6)
        case .processing:
            if interiorIndices.contains(index) {
                return 0.06
            }
            guard let pi = perimeterOrder.firstIndex(of: index) else { return 0 }
            let pixelPhase = Double(pi) / Double(perimeterOrder.count)
            let diff = fmod(phase - pixelPhase + 1.0, 1.0)
            let spread = 0.10
            return exp(-pow(min(diff, 1.0 - diff) / spread, 2))
        }
    }

    // MARK: - Dynamic Perimeter & Interior

    /// Computes clockwise perimeter indices for a rows×cols grid
    private func perimeterOrder() -> [Int] {
        var order: [Int] = []
        // Top row left to right
        for c in 0..<cols { order.append(c) }
        // Right column top+1 to bottom
        for r in 1..<rows { order.append(r * cols + (cols - 1)) }
        // Bottom row right-1 to left
        for c in stride(from: cols - 2, through: 0, by: -1) { order.append((rows - 1) * cols + c) }
        // Left column: middle rows from bottom-1 to row 1
        for r in stride(from: rows - 2, through: 1, by: -1) {
            order.append(r * cols)
        }
        return order
    }

    /// Interior indices (all middle rows and middle cols) for a rows×cols grid
    private func interiorIndices() -> Set<Int> {
        var interior = Set<Int>()
        for r in 1..<(rows - 1) {
            for c in 1..<(cols - 1) {
                interior.insert(r * cols + c)
            }
        }
        return interior
    }

    // MARK: - Per-State Color

    private func pixelColor(for state: SpinnerState) -> Color {
        switch state {
        case .listening: return Color(red: 0.40, green: 0.90, blue: 0.55)
        case .success:   return Color(red: 0.40, green: 0.90, blue: 0.55)
        case .error:     return Color(red: 0.90, green: 0.40, blue: 0.40)
        default:         return color
        }
    }

    // MARK: - Per-State Glow

    private func effectiveGlow(for state: SpinnerState, index: Int, interiorIndices: Set<Int>) -> Double {
        switch state {
        case .idle:
            return index == blinkPixel ? glowIntensity * 1.5 : glowIntensity * 0.3
        case .success:    return glowIntensity * 1.8
        case .error:      return glowIntensity * 1.4
        case .connecting: return interiorIndices.contains(index) ? glowIntensity * 0.2 : glowIntensity * 1.2
        case .processing: return interiorIndices.contains(index) ? glowIntensity * 0.2 : glowIntensity * 1.3
        default:          return glowIntensity
        }
    }

    // MARK: - Idle Blink

    private func startBlinkTimer() {
        blinkTimer?.invalidate()
        scheduleBlink()
    }

    private func scheduleBlink() {
        let delay = Double.random(in: 0.8...2.0)
        blinkTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            triggerBlink()
        }
    }

    private func triggerBlink() {
        // Pick from visible column range only
        let visibleIndices = (0..<rows).flatMap { row in
            (colStart..<colEnd).map { col in row * cols + col }
        }
        guard !visibleIndices.isEmpty else { return }
        blinkPixel = visibleIndices.randomElement()!
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
    var shadowsEnabled: Bool = true

    var body: some View {
        let dot = RoundedRectangle(cornerRadius: size * 0.15)
            .fill(color)
            .frame(width: size, height: size)
            .opacity(brightness)

        if shadowsEnabled && glowIntensity > 0.01 {
            dot
                .shadow(color: color.opacity(0.4 * glowIntensity * brightness), radius: 2 * glowIntensity)
                .shadow(color: color.opacity(0.15 * glowIntensity * brightness), radius: 6 * glowIntensity)
        } else {
            dot
        }
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
