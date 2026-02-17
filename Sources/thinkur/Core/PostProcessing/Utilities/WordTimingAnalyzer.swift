import Foundation

struct TimingGap {
    let index: Int
    let gap: Float
    let wordBefore: String
    let wordAfter: String
}

struct WordTimingAnalyzer {
    static func gaps(from timings: [WordTimingInfo]) -> [TimingGap] {
        guard timings.count >= 2 else { return [] }

        var result: [TimingGap] = []
        for i in 0..<(timings.count - 1) {
            let gap = timings[i + 1].start - timings[i].end
            result.append(TimingGap(
                index: i,
                gap: gap,
                wordBefore: timings[i].word,
                wordAfter: timings[i + 1].word
            ))
        }
        return result
    }

    static func medianGap(from timings: [WordTimingInfo]) -> Float {
        let allGaps = gaps(from: timings).map(\.gap).filter { $0 > 0 }.sorted()
        guard !allGaps.isEmpty else { return 0 }
        return allGaps[allGaps.count / 2]
    }

    static func adaptiveThresholds(from timings: [WordTimingInfo]) -> PauseThresholds {
        PauseThresholds.adaptive(from: timings)
    }
}
