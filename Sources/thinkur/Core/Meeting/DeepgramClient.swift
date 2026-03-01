import Foundation
import os

/// Sends audio to Deepgram's API for transcription + diarization and parses the result.
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

    func transcribe(audioURL: URL, apiKey: String) async throws -> TranscriptionResult {
        let audioData = try Data(contentsOf: audioURL)

        var request = URLRequest(url: URL(string:
            "https://api.deepgram.com/v1/listen?model=nova-2&diarize=true&punctuate=true&smart_format=true&utterances=true"
        )!)
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

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [String: Any],
              let channels = results["channels"] as? [[String: Any]],
              let firstChannel = channels.first,
              let alternatives = firstChannel["alternatives"] as? [[String: Any]],
              let firstAlt = alternatives.first,
              let words = firstAlt["words"] as? [[String: Any]] else {
            throw DeepgramError.decodingFailed
        }

        guard !words.isEmpty else {
            throw DeepgramError.noTranscription
        }

        let parsed: [DGWord] = words.compactMap { w in
            guard let word = w["punctuated_word"] as? String ?? w["word"] as? String,
                  let start = w["start"] as? Double,
                  let end = w["end"] as? Double,
                  let speaker = w["speaker"] as? Int else { return nil }
            return DGWord(word: word, start: start, end: end, speaker: speaker)
        }

        // Group consecutive same-speaker words into segments
        let segments = groupIntoSegments(parsed)
        let speakerCount = Set(parsed.map(\.speaker)).count

        Logger.app.info("Deepgram: \(segments.count) segments, \(speakerCount) speakers, \(parsed.count) words")
        return TranscriptionResult(segments: segments, speakerCount: speakerCount)
    }

    /// Validates an API key with a minimal request.
    func validate(apiKey: String) async -> Bool {
        // Send a tiny silent WAV to check authentication
        var request = URLRequest(url: URL(string:
            "https://api.deepgram.com/v1/listen?model=nova-2"
        )!)
        request.httpMethod = "POST"
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
        // Minimal valid WAV header (44 bytes, 0 audio samples)
        request.httpBody = minimalWAV()

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as! HTTPURLResponse).statusCode
            // 200 = valid key (even with empty audio), 401/403 = bad key
            return status == 200
        } catch {
            return false
        }
    }

    private func minimalWAV() -> Data {
        var data = Data()
        // RIFF header
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        data.append(contentsOf: withUnsafeBytes(of: UInt32(36).littleEndian) { Array($0) }) // file size - 8
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"
        // fmt chunk
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) }) // chunk size
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // PCM
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // mono
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16000).littleEndian) { Array($0) }) // sample rate
        data.append(contentsOf: withUnsafeBytes(of: UInt32(32000).littleEndian) { Array($0) }) // byte rate
        data.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) })  // block align
        data.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) }) // bits per sample
        // data chunk (empty)
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        data.append(contentsOf: withUnsafeBytes(of: UInt32(0).littleEndian) { Array($0) })  // data size
        return data
    }

    // MARK: - Segment Grouping

    private struct DGWord {
        let word: String
        let start: Double
        let end: Double
        let speaker: Int
    }

    private func groupIntoSegments(_ words: [DGWord]) -> [AttributedSegment] {
        guard let first = words.first else { return [] }

        var segments: [AttributedSegment] = []
        var currentSpeaker = first.speaker
        var currentWords: [String] = [first.word]
        var segStart = first.start
        var segEnd = first.end

        for word in words.dropFirst() {
            if word.speaker == currentSpeaker {
                currentWords.append(word.word)
                segEnd = word.end
            } else {
                segments.append(AttributedSegment(
                    speakerId: "speaker-\(currentSpeaker)",
                    text: currentWords.joined(separator: " "),
                    startTime: segStart,
                    endTime: segEnd
                ))
                currentSpeaker = word.speaker
                currentWords = [word.word]
                segStart = word.start
                segEnd = word.end
            }
        }

        // Final segment
        segments.append(AttributedSegment(
            speakerId: "speaker-\(currentSpeaker)",
            text: currentWords.joined(separator: " "),
            startTime: segStart,
            endTime: segEnd
        ))

        return segments
    }
}
