/// Sorted-array interval tree for efficient speaker segment overlap queries.
/// Ported from WhisperX diarize.py.
struct IntervalTree<T> {
    struct Entry {
        let start: Double
        let end: Double
        let value: T
    }

    private let entries: [Entry]  // sorted by start

    init(_ entries: [Entry]) {
        self.entries = entries.sorted { $0.start < $1.start }
    }

    /// Find all entries overlapping [queryStart, queryEnd].
    /// Uses binary search to find the starting position, then scans forward.
    func query(start queryStart: Double, end queryEnd: Double) -> [Entry] {
        guard !entries.isEmpty else { return [] }

        // Binary search: find first entry whose start < queryEnd
        // Any entry starting at or after queryEnd can't overlap
        var lo = 0
        var hi = entries.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if entries[mid].start < queryEnd {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        // lo = first entry with start >= queryEnd; candidates are entries[0..<lo]

        var result: [Entry] = []
        for i in 0..<lo {
            // Overlap exists when entry.end > queryStart AND entry.start < queryEnd
            if entries[i].end > queryStart {
                result.append(entries[i])
            }
        }
        return result
    }

    /// Find the entry nearest to `time` (by midpoint distance).
    func findNearest(time: Double) -> Entry? {
        guard !entries.isEmpty else { return nil }

        var bestEntry = entries[0]
        var bestDist = abs(time - (bestEntry.start + bestEntry.end) / 2.0)

        for entry in entries.dropFirst() {
            let mid = (entry.start + entry.end) / 2.0
            let dist = abs(time - mid)
            if dist < bestDist {
                bestDist = dist
                bestEntry = entry
            }
        }
        return bestEntry
    }
}
