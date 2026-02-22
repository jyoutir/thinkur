import Foundation

struct PauseThresholds {
    let sentenceBreak: Float
    let clauseBreak: Float

    static let `default` = PauseThresholds(sentenceBreak: 1.5, clauseBreak: 0.4)

    static func adaptive(from timings: [WordTimingInfo]) -> PauseThresholds {
        guard timings.count >= 5 else { return .default }

        var gaps: [Float] = []
        for i in 0..<(timings.count - 1) {
            let gap = timings[i + 1].start - timings[i].end
            if gap > 0 { gaps.append(gap) }
        }

        guard !gaps.isEmpty else { return .default }

        let sorted = gaps.sorted()
        let median = sorted[sorted.count / 2]

        return PauseThresholds(
            sentenceBreak: max(median * 3.0, 1.0),
            clauseBreak: max(median * 1.5, 0.2)
        )
    }
}
