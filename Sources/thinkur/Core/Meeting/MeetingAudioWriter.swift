import AVFoundation
import Foundation
import os

/// Streams 16kHz mono Float32 audio to a WAV file on disk.
/// Thread-safe via a serial dispatch queue.
final class MeetingAudioWriter {
    private let fileURL: URL
    private var audioFile: AVAudioFile?
    private let queue = DispatchQueue(label: "com.thinkur.meetingAudioWriter")
    private let format: AVAudioFormat
    private var totalFramesWritten: AVAudioFrameCount = 0

    init() throws {
        let meetingsDir = Constants.appSupportDirectory
            .appendingPathComponent("meetings", isDirectory: true)
        try FileManager.default.createDirectory(at: meetingsDir, withIntermediateDirectories: true)

        let filename = UUID().uuidString + ".wav"
        self.fileURL = meetingsDir.appendingPathComponent(filename)

        guard let fmt = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Constants.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw MeetingAudioWriterError.invalidFormat
        }
        self.format = fmt

        self.audioFile = try AVAudioFile(
            forWriting: fileURL,
            settings: fmt.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )

        Logger.app.info("MeetingAudioWriter created: \(filename)")
    }

    /// Creates a writer for a named track within a shared meeting.
    /// File is named `{meetingId}-{trackName}.wav` in the meetings directory.
    init(trackName: String, meetingId: String) throws {
        let meetingsDir = Constants.appSupportDirectory
            .appendingPathComponent("meetings", isDirectory: true)
        try FileManager.default.createDirectory(at: meetingsDir, withIntermediateDirectories: true)

        let filename = "\(meetingId)-\(trackName).wav"
        self.fileURL = meetingsDir.appendingPathComponent(filename)

        guard let fmt = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Constants.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw MeetingAudioWriterError.invalidFormat
        }
        self.format = fmt

        self.audioFile = try AVAudioFile(
            forWriting: fileURL,
            settings: fmt.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )

        Logger.app.info("MeetingAudioWriter created: \(filename)")
    }

    /// Append audio samples to the WAV file. Thread-safe.
    func appendSamples(_ samples: [Float]) {
        guard !samples.isEmpty else { return }
        queue.sync {
            guard let audioFile else { return }
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(samples.count)
            ) else { return }

            buffer.frameLength = AVAudioFrameCount(samples.count)
            if let channelData = buffer.floatChannelData {
                samples.withUnsafeBufferPointer { src in
                    channelData[0].update(from: src.baseAddress!, count: samples.count)
                }
            }

            do {
                try audioFile.write(from: buffer)
                totalFramesWritten += buffer.frameLength
            } catch {
                Logger.app.error("MeetingAudioWriter write error: \(error)")
            }
        }
    }

    /// Current duration of written audio in seconds.
    var currentDuration: Double {
        queue.sync {
            Double(totalFramesWritten) / Constants.sampleRate
        }
    }

    /// The relative path component for the audio file (e.g. "abc-123.wav").
    var relativePath: String {
        fileURL.lastPathComponent
    }

    /// Finalize and close the file. Returns the file URL.
    func finalize() -> URL {
        queue.sync {
            audioFile = nil
        }
        Logger.app.info("MeetingAudioWriter finalized: \(self.totalFramesWritten) frames")
        return fileURL
    }

    /// Delete the audio file from disk.
    static func deleteAudioFile(relativePath: String) {
        let url = Constants.appSupportDirectory
            .appendingPathComponent("meetings", isDirectory: true)
            .appendingPathComponent(relativePath)
        try? FileManager.default.removeItem(at: url)
    }

    /// Delete multiple audio files from disk, skipping nil paths.
    static func deleteAudioFiles(relativePaths: [String?]) {
        for path in relativePaths {
            guard let path else { continue }
            deleteAudioFile(relativePath: path)
        }
    }
}

enum MeetingAudioWriterError: Error, LocalizedError {
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Failed to create audio format for meeting recording"
        }
    }
}
