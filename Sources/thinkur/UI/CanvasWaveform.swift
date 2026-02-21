import SwiftUI

/// High-performance Canvas-based waveform visualizer
///
/// Uses SwiftUI Canvas API for direct Metal rendering instead of individual view-per-pixel architecture.
/// This eliminates the performance bottleneck of hundreds of shadow layers and view diffing.
///
/// Performance benefits over view-based approach:
/// - 1 view instead of 170 individual PixelDot views
/// - 1 blur operation instead of 340 shadow layers
/// - Direct Metal rendering path (no SwiftUI view hierarchy overhead)
/// - Estimated <3% CPU at 30fps (vs 99% with 21-row view-based grid)
struct CanvasWaveform: View {
    var audioAmplitudes: [Double]
    var amplitudesStartIndex: Int
    var color: Color
    var glowIntensity: Double
    var cols: Int = 34
    var rows: Int = 5
    var pixelSize: CGFloat = 6   // Taller than current 3pt for better peak definition
    var spacing: CGFloat = 1

    /// Precomputed amplitude curve lookup table (same as ClaudePixelSpinner)
    /// Uses 0.4 exponent for better sensitivity with quiet sounds
    private static let amplitudeCurveCache: [Double] = {
        (0...100).map { i in
            let normalized = Double(i) / 100.0
            return pow(normalized, 0.4)
        }
    }()

    var body: some View {
        Canvas { context, size in
            let centerRow = rows / 2

            for col in 0..<cols {
                // Get amplitude for this column
                let amplitude = getAmplitude(for: col)

                // Use precomputed curve cache instead of pow() for performance
                let curveIndex = min(Int(amplitude * 100), 100)
                let curved = Self.amplitudeCurveCache[curveIndex]

                // Column brightness: 0.4-1.0 range (same as current symmetric waveform)
                // Low amplitude: 0.4 (visible dark green baseline)
                // High amplitude: 1.0 (vivid bright green)
                let columnBrightness = 0.4 + (curved * 0.6)

                for row in 0..<rows {
                    let distance = abs(row - centerRow)

                    // Visibility thresholds (more sensitive than current for better peak definition)
                    let threshold: Double = switch distance {
                    case 0:  0.0   // Center row always visible
                    case 1:  0.08  // More sensitive than current 0.10
                    case 2:  0.20  // More sensitive than current 0.25
                    default: 1.0
                    }

                    guard curved >= threshold else { continue }

                    // Apply tapered visibility (trim edges for rounder shape, same as current)
                    // Center row: all columns visible
                    // Adjacent rows (distance 1): trim 1 from each end
                    // Edge rows (distance 2): trim 2 from each end
                    let trimAmount = distance
                    guard col >= trimAmount && col < (cols - trimAmount) else { continue }

                    // Calculate pixel position
                    let x = CGFloat(col) * (pixelSize + spacing)
                    let y = CGFloat(row) * (pixelSize + spacing)
                    let rect = CGRect(x: x, y: y, width: pixelSize, height: pixelSize)

                    // Draw rounded rectangle with column-coherent brightness
                    let path = RoundedRectangle(cornerRadius: pixelSize * 0.15)
                        .path(in: rect)

                    context.fill(path, with: .color(color.opacity(columnBrightness)))
                }
            }
        }
        .frame(
            width: CGFloat(cols) * (pixelSize + spacing) - spacing,
            height: CGFloat(rows) * (pixelSize + spacing) - spacing
        )
        .blur(radius: 4 * glowIntensity)  // Single blur on entire canvas (not per-pixel)
        .drawingGroup()  // Forces Metal rendering for hardware acceleration
    }

    /// Get amplitude for a specific column (same logic as ClaudePixelSpinner)
    /// Maps columns to recent amplitude samples, right-to-left (newest on right)
    private func getAmplitude(for col: Int) -> Double {
        guard !audioAmplitudes.isEmpty else { return 0.0 }

        let offset = audioAmplitudes.count >= cols ? (audioAmplitudes.count - cols + col) : col
        let sampleIndex = (amplitudesStartIndex + offset) % audioAmplitudes.count
        return audioAmplitudes[sampleIndex]
    }
}
