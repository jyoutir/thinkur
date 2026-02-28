import Accelerate
import AVFoundation
import Foundation
import os
import ScreenCaptureKit

final class SystemAudioCaptureManager: NSObject, @unchecked Sendable {
    private var stream: SCStream?
    private(set) var isCapturing = false

    // Ring buffer: ~2 seconds at 16kHz
    private let ringCapacity = 32_000
    private var ringBuffer: [Float]
    private var writeIndex = 0
    private var availableSamples = 0
    private let lock = NSLock()

    private let targetSampleRate = Constants.sampleRate
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: Constants.sampleRate,
        channels: 1,
        interleaved: false
    )!

    override init() {
        ringBuffer = [Float](repeating: 0, count: 32_000)
        super.init()
    }

    // MARK: - Capture

    func startCapture() async throws {
        guard !isCapturing else { return }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)

        guard let display = content.displays.first else {
            throw SystemAudioCaptureError.noDisplay
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])

        let config = SCStreamConfiguration()
        // Audio settings
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = Int(targetSampleRate)
        config.channelCount = 1
        // Minimal video to satisfy API requirements
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1) // 1 fps

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global(qos: .userInteractive))

        try await stream.startCapture()

        self.stream = stream
        isCapturing = true
        Logger.app.info("System audio capture started")
    }

    func stopCapture() async {
        guard isCapturing, let stream else { return }
        do {
            try await stream.stopCapture()
        } catch {
            Logger.app.warning("System audio stop error: \(error)")
        }
        self.stream = nil
        isCapturing = false

        lock.lock()
        writeIndex = 0
        availableSamples = 0
        lock.unlock()

        Logger.app.info("System audio capture stopped")
    }

    // MARK: - Ring Buffer Read

    /// Read exactly `count` samples from the ring buffer, zero-padding if under-filled.
    /// Called from the mic tap audio thread.
    func readSamples(count: Int) -> [Float] {
        lock.lock()
        defer { lock.unlock() }

        let toRead = min(count, availableSamples)
        var output = [Float](repeating: 0, count: count)

        if toRead > 0 {
            let readStart = (writeIndex - availableSamples + ringCapacity) % ringCapacity

            if readStart + toRead <= ringCapacity {
                output.replaceSubrange(0..<toRead, with: ringBuffer[readStart..<(readStart + toRead)])
            } else {
                // Wraps around
                let firstPart = ringCapacity - readStart
                output.replaceSubrange(0..<firstPart, with: ringBuffer[readStart..<ringCapacity])
                output.replaceSubrange(firstPart..<toRead, with: ringBuffer[0..<(toRead - firstPart)])
            }

            availableSamples -= toRead
        }

        return output
    }
}

// MARK: - SCStreamDelegate

extension SystemAudioCaptureManager: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        Logger.app.error("System audio stream stopped with error: \(error)")
        isCapturing = false
    }
}

// MARK: - SCStreamOutput

extension SystemAudioCaptureManager: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        guard let blockBuffer = sampleBuffer.dataBuffer else { return }

        let length = CMBlockBufferGetDataLength(blockBuffer)
        guard length > 0 else { return }

        var dataPointer: UnsafeMutablePointer<Int8>?
        var lengthAtOffset: Int = 0
        let status = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: &lengthAtOffset, totalLengthOut: nil, dataPointerOut: &dataPointer)
        guard status == kCMBlockBufferNoErr, let dataPointer else { return }

        // ScreenCaptureKit delivers Float32 samples at our requested 16kHz mono
        let floatCount = lengthAtOffset / MemoryLayout<Float>.size
        guard floatCount > 0 else { return }

        let floatPointer = UnsafeRawPointer(dataPointer).bindMemory(to: Float.self, capacity: floatCount)

        lock.lock()
        for i in 0..<floatCount {
            ringBuffer[writeIndex] = floatPointer[i]
            writeIndex = (writeIndex + 1) % ringCapacity
        }
        availableSamples = min(availableSamples + floatCount, ringCapacity)
        lock.unlock()
    }
}

// MARK: - Error

enum SystemAudioCaptureError: LocalizedError {
    case noDisplay

    var errorDescription: String? {
        switch self {
        case .noDisplay:
            return "No display found for system audio capture"
        }
    }
}
