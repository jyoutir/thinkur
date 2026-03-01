/// A transcribed text segment attributed to a speaker.
struct AttributedSegment: Sendable {
    let speakerId: String
    let text: String
    let startTime: Double
    let endTime: Double
}
