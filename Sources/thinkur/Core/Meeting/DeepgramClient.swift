import AVFoundation
import Foundation
import os

/// Sends audio to Deepgram's API for transcription and diarization.
/// Mic and system audio are sent as separate requests for reliable speaker attribution.
actor DeepgramClient {
    struct TranscriptionResult: Sendable {
        let segments: [AttributedSegment]
        let speakerCount: Int
    }

    enum DeepgramError: LocalizedError {
        case invalidAPIKey
        case uploadFailed(statusCode: Int, message: String)
        case decodingFailed
        case noTranscription

        var errorDescription: String? {
            switch self {
            case .invalidAPIKey: "Invalid Deepgram API key."
            case .uploadFailed(let code, let msg): "Deepgram returned \(code): \(msg)"
            case .decodingFailed: "Failed to parse Deepgram response."
            case .noTranscription: "Deepgram returned no transcription."
            }
        }
    }

    // MARK: - Public API

    /// Transcribes a meeting from separate mic and system audio files.
    /// Runs both requests in parallel, merges results by timestamp.
    func transcribeMeeting(micURL: URL, systemURL: URL, apiKey: String) async throws -> TranscriptionResult {
        let systemHasAudio = wavHasAudio(url: systemURL)

        let micWords: [TimedWord]
        let sysWords: [TimedWord]

        if systemHasAudio {
            async let mic = transcribeMic(audioURL: micURL, apiKey: apiKey)
            async let sys = transcribeSystem(audioURL: systemURL, apiKey: apiKey)
            micWords = try await mic
            sysWords = try await sys
        } else {
            Logger.app.info("System audio empty — mic-only transcript")
            micWords = try await transcribeMic(audioURL: micURL, apiKey: apiKey)
            sysWords = []
        }

        let allWords = (micWords + sysWords).sorted { $0.start < $1.start }

        guard !allWords.isEmpty else {
            throw DeepgramError.noTranscription
        }

        let segments = groupIntoSegments(allWords)
        let speakerCount = Set(allWords.map(\.speakerId)).count

        Logger.app.info("Deepgram: \(segments.count) segments, \(speakerCount) speakers, \(allWords.count) words")
        return TranscriptionResult(segments: segments, speakerCount: speakerCount)
    }

    /// Validates an API key with a minimal request.
    func validate(apiKey: String) async -> Bool {
        var request = URLRequest(url: URL(string:
            "https://api.deepgram.com/v1/listen?model=nova-3"
        )!)
        request.httpMethod = "POST"
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
        request.httpBody = minimalWAV()

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as! HTTPURLResponse).statusCode
            return status == 200
        } catch {
            return false
        }
    }

    // MARK: - Mic Transcription (no diarization)

    /// Transcribes mic audio. All words are attributed to the local user.
    private func transcribeMic(audioURL: URL, apiKey: String) async throws -> [TimedWord] {
        let url = "https://api.deepgram.com/v1/listen?model=nova-3&punctuate=true&smart_format=true"
        let data = try await sendRequest(audioURL: audioURL, apiKey: apiKey, url: url)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [String: Any],
              let channels = results["channels"] as? [[String: Any]],
              let channel = channels.first,
              let alternatives = channel["alternatives"] as? [[String: Any]],
              let firstAlt = alternatives.first,
              let words = firstAlt["words"] as? [[String: Any]] else {
            return []
        }

        return words.compactMap { w -> TimedWord? in
            guard let word = w["punctuated_word"] as? String ?? w["word"] as? String,
                  let start = w["start"] as? Double,
                  let end = w["end"] as? Double else { return nil }
            return TimedWord(word: word, start: start, end: end, speakerId: "local")
        }
    }

    // MARK: - System Transcription (with diarization)

    /// Transcribes system audio with diarization for multiple remote speakers.
    private func transcribeSystem(audioURL: URL, apiKey: String) async throws -> [TimedWord] {
        let url = "https://api.deepgram.com/v1/listen?model=nova-3&diarize=true&punctuate=true&smart_format=true"
        let data = try await sendRequest(audioURL: audioURL, apiKey: apiKey, url: url)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [String: Any],
              let channels = results["channels"] as? [[String: Any]],
              let channel = channels.first,
              let alternatives = channel["alternatives"] as? [[String: Any]],
              let firstAlt = alternatives.first,
              let words = firstAlt["words"] as? [[String: Any]] else {
            return []
        }

        return words.compactMap { w -> TimedWord? in
            guard let word = w["punctuated_word"] as? String ?? w["word"] as? String,
                  let start = w["start"] as? Double,
                  let end = w["end"] as? Double else { return nil }
            let speaker = w["speaker"] as? Int ?? 0
            return TimedWord(word: word, start: start, end: end, speakerId: "remote-\(speaker + 1)")
        }
    }

    // MARK: - HTTP

    private func sendRequest(audioURL: URL, apiKey: String, url: String) async throws -> Data {
        let audioData = try Data(contentsOf: audioURL)

        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
        request.httpBody = audioData

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw DeepgramError.invalidAPIKey
            }
            throw DeepgramError.uploadFailed(statusCode: httpResponse.statusCode, message: body)
        }

        return data
    }

    // MARK: - Helpers

    private struct TimedWord {
        let word: String
        let start: Double
        let end: Double
        let speakerId: String
    }

    private func groupIntoSegments(_ words: [TimedWord]) -> [AttributedSegment] {
        guard let first = words.first else { return [] }

        var segments: [AttributedSegment] = []
        var currentSpeaker = first.speakerId
        var currentWords: [String] = [first.word]
        var segStart = first.start
        var segEnd = first.end

        for word in words.dropFirst() {
            if word.speakerId == currentSpeaker {
                currentWords.append(word.word)
                segEnd = word.end
            } else {
                segments.append(AttributedSegment(
                    speakerId: currentSpeaker,
                    text: currentWords.joined(separator: " "),
                    startTime: segStart,
                    endTime: segEnd
                ))
                currentSpeaker = word.speakerId
                currentWords = [word.word]
                segStart = word.start
                segEnd = word.end
            }
        }

        segments.append(AttributedSegment(
            speakerId: currentSpeaker,
            text: currentWords.joined(separator: " "),
            startTime: segStart,
            endTime: segEnd
        ))

        return segments
    }

    /// Checks if a WAV file has any non-silent audio data.
    private func wavHasAudio(url: URL) -> Bool {
        guard let file = try? AVAudioFile(forReading: url) else { return false }
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount) else {
            return false
        }
        do {
            try file.read(into: buffer)
        } catch {
            return false
        }
        guard let channelData = buffer.floatChannelData else { return false }
        let samples = UnsafeBufferPointer(start: channelData[0], count: Int(buffer.frameLength))
        // Check if any sample exceeds a minimal threshold
        return samples.contains { abs($0) > 0.0001 }
    }

    private func minimalWAV() -> Data {
        var data = Data()
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        data.append(contentsOf: withUnsafeBytes(of: UInt32(36).littleEndian) { Array($0) })
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // PCM
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // mono
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16000).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt32(32000).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) })
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        data.append(contentsOf: withUnsafeBytes(of: UInt32(0).littleEndian) { Array($0) })
        return data
    }
}
