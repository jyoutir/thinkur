import Combine
import Foundation

/// Rolling amplitude buffer for waveform UI.
/// Polls audio level at 80ms intervals, applies EMA smoothing,
/// and maintains a fixed-size ring buffer.
@MainActor
final class AudioAmplitudeProvider: ObservableObject {
    @Published var amplitudes: [Double]

    private let bufferSize: Int
    private let smoothingFactor: Double
    private var ringBuffer: [Double]
    private var writeIndex = 0
    private var timer: Timer?
    private var levelSource: (() -> Float)?

    init(bufferSize: Int = 30, smoothingFactor: Double = 0.7) {
        self.bufferSize = bufferSize
        self.smoothingFactor = smoothingFactor
        self.ringBuffer = Array(repeating: 0.0, count: bufferSize)
        self.amplitudes = Array(repeating: 0.0, count: bufferSize)
    }

    func startPolling(source: @escaping () -> Float) {
        levelSource = source
        ringBuffer = Array(repeating: 0.0, count: bufferSize)
        writeIndex = 0
        amplitudes = Array(repeating: 0.0, count: bufferSize)
        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
        levelSource = nil
        ringBuffer = Array(repeating: 0.0, count: bufferSize)
        writeIndex = 0
        amplitudes = Array(repeating: 0.0, count: bufferSize)
    }

    private func tick() {
        guard let source = levelSource else { return }
        let raw = Double(source())
        let previousIndex = writeIndex == 0 ? bufferSize - 1 : writeIndex - 1
        let previous = ringBuffer[previousIndex]
        let smoothed = previous * (1.0 - smoothingFactor) + raw * smoothingFactor

        ringBuffer[writeIndex] = smoothed
        writeIndex = (writeIndex + 1) % bufferSize

        // Publish ordered snapshot from ring buffer
        if writeIndex == 0 {
            amplitudes = ringBuffer
        } else {
            amplitudes = Array(ringBuffer[writeIndex...]) + Array(ringBuffer[..<writeIndex])
        }
    }
}
