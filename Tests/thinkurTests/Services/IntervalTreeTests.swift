@testable import thinkur
import Testing

@Suite("IntervalTree")
struct IntervalTreeTests {

    @Test("Query finds overlapping entries")
    func queryOverlap() {
        let tree = IntervalTree<String>([
            .init(start: 0, end: 5, value: "A"),
            .init(start: 3, end: 8, value: "B"),
            .init(start: 10, end: 15, value: "C"),
        ])
        let results = tree.query(start: 4, end: 6)
        let values = results.map(\.value).sorted()
        #expect(values == ["A", "B"])
    }

    @Test("Query returns empty for no overlap")
    func queryNoOverlap() {
        let tree = IntervalTree<String>([
            .init(start: 0, end: 2, value: "A"),
            .init(start: 5, end: 7, value: "B"),
        ])
        let results = tree.query(start: 3, end: 4)
        #expect(results.isEmpty)
    }

    @Test("Query on empty tree returns empty")
    func queryEmptyTree() {
        let tree = IntervalTree<String>([])
        let results = tree.query(start: 0, end: 10)
        #expect(results.isEmpty)
    }

    @Test("Query with single entry that overlaps")
    func querySingleOverlap() {
        let tree = IntervalTree<String>([
            .init(start: 2, end: 6, value: "X"),
        ])
        let results = tree.query(start: 4, end: 8)
        #expect(results.count == 1)
        #expect(results[0].value == "X")
    }

    @Test("Query does not include touching boundaries")
    func queryTouchingBoundary() {
        let tree = IntervalTree<String>([
            .init(start: 0, end: 5, value: "A"),
            .init(start: 5, end: 10, value: "B"),
        ])
        // Query [5, 8) should include B but not A (A.end == query.start is not overlap)
        let results = tree.query(start: 5, end: 8)
        #expect(results.count == 1)
        #expect(results[0].value == "B")
    }

    @Test("findNearest returns closest entry by midpoint")
    func findNearest() {
        let tree = IntervalTree<String>([
            .init(start: 0, end: 2, value: "A"),   // midpoint = 1
            .init(start: 5, end: 7, value: "B"),   // midpoint = 6
            .init(start: 10, end: 12, value: "C"), // midpoint = 11
        ])
        let nearest = tree.findNearest(time: 5.5)
        #expect(nearest?.value == "B")
    }

    @Test("findNearest on empty tree returns nil")
    func findNearestEmpty() {
        let tree = IntervalTree<String>([])
        #expect(tree.findNearest(time: 5) == nil)
    }

    @Test("findNearest with single entry")
    func findNearestSingle() {
        let tree = IntervalTree<String>([
            .init(start: 100, end: 200, value: "only"),
        ])
        let nearest = tree.findNearest(time: 0)
        #expect(nearest?.value == "only")
    }
}
