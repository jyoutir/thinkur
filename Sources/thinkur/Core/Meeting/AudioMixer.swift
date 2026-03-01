import AVFoundation
import Foundation
import os

/// Mixes mic and system audio WAV files into a single mono WAV for Deepgram.
enum AudioMixer {
    enum MixerError: LocalizedError {
        case readFailed(String)
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .readFailed(let detail): "Failed to read audio: \(detail)"
            case .writeFailed(let detail): "Failed to write mixed audio: \(detail)"
            }
        }
    }

    /// Mixes two 16kHz mono Float32 WAV files into a temp file.
    /// Returns the URL of the mixed WAV.
    static func mix(micURL: URL, systemURL: URL) throws -> URL {
        let micFile = try AVAudioFile(forReading: micURL)
        let sysFile = try AVAudioFile(forReading: systemURL)

        let format = micFile.processingFormat
        let micFrames = AVAudioFrameCount(micFile.length)
        let sysFrames = AVAudioFrameCount(sysFile.length)
        let totalFrames = max(micFrames, sysFrames)

        guard totalFrames > 0 else {
            throw MixerError.readFailed("Both audio files are empty")
        }

        guard let micBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: micFrames),
              let sysBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: sysFrames) else {
            throw MixerError.readFailed("Could not allocate buffers")
        }

        try micFile.read(into: micBuffer)
        try sysFile.read(into: sysBuffer)

        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else {
            throw MixerError.writeFailed("Could not allocate output buffer")
        }
        outBuffer.frameLength = totalFrames

        let outPtr = outBuffer.floatChannelData![0]
        let micPtr = micBuffer.floatChannelData![0]
        let sysPtr = sysBuffer.floatChannelData![0]

        // Mix: add both sources scaled by 0.5 to prevent clipping
        for i in 0..<Int(totalFrames) {
            let mic: Float = i < Int(micFrames) ? micPtr[i] : 0
            let sys: Float = i < Int(sysFrames) ? sysPtr[i] : 0
            outPtr[i] = (mic + sys) * 0.5
        }

        // Write to temp file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("thinkur-mixed-\(UUID().uuidString).wav")
        let outFile = try AVAudioFile(
            forWriting: tempURL,
            settings: format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        try outFile.write(from: outBuffer)

        Logger.app.info("AudioMixer: mixed \(micFrames) mic + \(sysFrames) sys frames -> \(totalFrames) frames")
        return tempURL
    }
}
