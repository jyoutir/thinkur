import Foundation

/// Rolling amplitude buffer for waveform UI.
/// Polls audio level at 80ms intervals, applies EMA smoothing,
/// and maintains a fixed-size ring buffer.
@MainActor
@Observable
final class AudioAmplitudeProvider {
    var amplitudes: [Double]
    var amplitudesStartIndex: Int = 0

    private let bufferSize: Int
    private let smoothingFactor: Double
    private let pollingInterval: TimeInterval
    private var ringBuffer: [Double]
    private var writeIndex = 0
    private var timer: Timer?
    private var levelSource: (() -> Float)?

    init(
        bufferSize: Int = 40,
        smoothingFactor: Double = 0.7,
        pollingInterval: TimeInterval = 1.0 / 30.0
    ) {
        self.bufferSize = bufferSize
        self.smoothingFactor = smoothingFactor
        self.pollingInterval = pollingInterval
        self.ringBuffer = Array(repeating: 0.0, count: bufferSize)
        self.amplitudes = Array(repeating: 0.0, count: bufferSize)
    }

    func startPolling(source: @escaping () -> Float) {
        timer?.invalidate()
        levelSource = source
        zeroBuffers()
        writeIndex = 0
        amplitudesStartIndex = 0
        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        timer?.tolerance = pollingInterval * 0.2
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
        levelSource = nil
        zeroBuffers()
        writeIndex = 0
        amplitudesStartIndex = 0
    }

    private func zeroBuffers() {
        for i in ringBuffer.indices {
            ringBuffer[i] = 0.0
            amplitudes[i] = 0.0
        }
    }

    private func tick() {
        guard let source = levelSource else { return }
        let raw = Double(source())
        let previousIndex = writeIndex == 0 ? bufferSize - 1 : writeIndex - 1
        let previous = ringBuffer[previousIndex]
        let smoothed = previous * (1.0 - smoothingFactor) + raw * smoothingFactor

        ringBuffer[writeIndex] = smoothed
        // Mutate in-place instead of replacing the whole array
        amplitudes[writeIndex] = smoothed
        writeIndex = (writeIndex + 1) % bufferSize
        amplitudesStartIndex = writeIndex
    }
}
