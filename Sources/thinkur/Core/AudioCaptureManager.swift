import Accelerate
import AVFAudio
import AVFoundation
import os

final class AudioCaptureManager: AudioCapturing {
    private let audioEngine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private let bufferQueue = DispatchQueue(label: "com.thinkur.audioBuffer")
    private var converter: AVAudioConverter?
    private let targetFormat: AVAudioFormat

    private(set) var isCapturing = false

    /// Current audio level 0.0–1.0 (RMS), updated every buffer callback (~23ms at 1024/44.1kHz)
    var currentAudioLevel: Float = 0.0

    init() {
        targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Constants.sampleRate,
            channels: 1,
            interleaved: false
        )!
    }

    func startCapture() throws {
        guard !isCapturing else { return }

        // Defense-in-depth: refuse to start if microphone permission is not granted,
        // even if callers forgot to check.
        guard AVAudioApplication.shared.recordPermission == .granted else {
            Logger.audio.error("Microphone permission not granted — refusing to start capture")
            throw AudioCaptureError.microphonePermissionDenied
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0 else {
            Logger.audio.error("Invalid input format: sample rate is 0")
            throw AudioCaptureError.invalidInputFormat
        }

        guard let conv = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            Logger.audio.error("Failed to create audio converter from \(inputFormat) to \(self.targetFormat)")
            throw AudioCaptureError.converterCreationFailed
        }
        converter = conv

        bufferQueue.sync {
            audioBuffer.removeAll(keepingCapacity: true)
            audioBuffer.reserveCapacity(Int(Constants.sampleRate) * 30)
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.processInputBuffer(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isCapturing = true
        Logger.audio.info("Audio capture started at \(inputFormat.sampleRate)Hz, converting to \(Constants.sampleRate)Hz")
    }

    func stopCapture() -> [Float] {
        guard isCapturing else { return [] }

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioEngine.reset()   // Release audio hardware (audio units + aggregate device)
        converter = nil       // Drop stale converter (will be recreated on next start)
        isCapturing = false

        let samples = bufferQueue.sync {
            var result: [Float] = []
            swap(&result, &audioBuffer)
            return result
        }

        let duration = Double(samples.count) / Constants.sampleRate
        Logger.audio.info("Audio capture stopped: \(samples.count) samples (\(String(format: "%.1f", duration))s)")
        return samples
    }

    private func processInputBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let converter else { return }

        let ratio = Constants.sampleRate / buffer.format.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        guard outputFrameCount > 0 else { return }

        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputFrameCount
        ) else { return }

        var inputConsumed = false
        let status = converter.convert(to: convertedBuffer, error: nil) { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputConsumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard status != .error,
              let channelData = convertedBuffer.floatChannelData else { return }

        let frameLength = Int(convertedBuffer.frameLength)

        // Vectorized RMS via Accelerate (replaces reduce-based calculation)
        var rms: Float = 0
        vDSP_rmsqv(channelData[0], 1, &rms, vDSP_Length(frameLength))
        // Increased gain from 6.0 to 12.0 for better whisper sensitivity
        let normalized = min(rms * 12.0, 1.0)
        currentAudioLevel = normalized

        bufferQueue.sync {
            audioBuffer.append(contentsOf: UnsafeBufferPointer(
                start: channelData[0],
                count: frameLength
            ))
        }
    }
}

enum AudioCaptureError: Error, LocalizedError {
    case microphonePermissionDenied
    case invalidInputFormat
    case converterCreationFailed

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone permission is required to record audio"
        case .invalidInputFormat:
            return "Microphone input format is invalid"
        case .converterCreationFailed:
            return "Failed to create audio format converter"
        }
    }
}
