import Testing
@testable import thinkur

@Suite("ListMarkerMatcher")
struct ListMarkerMatcherTests {
    @Test func detectsNumberedMarker() {
        let matches = ListMarkerMatcher.findMarkers(in: "item one buy groceries item two clean house")
        let numbered = matches.filter { $0.category == "numbered" }
        #expect(numbered.count == 2)
        #expect(numbered[0].itemNumber == 1)
        #expect(numbered[1].itemNumber == 2)
    }

    @Test func detectsOrdinalMarker() {
        let matches = ListMarkerMatcher.findMarkers(in: "firstly we need to plan secondly we execute")
        let ordinals = matches.filter { $0.category == "ordinal" }
        #expect(ordinals.count == 2)
    }

    @Test func detectsBulletMarker() {
        let matches = ListMarkerMatcher.findMarkers(in: "bullet point apples bullet point oranges")
        let bullets = matches.filter { $0.category == "bullet" }
        #expect(bullets.count == 2)
    }

    @Test func returnsEmptyForPlainText() {
        let matches = ListMarkerMatcher.findMarkers(in: "the weather is nice today")
        #expect(matches.isEmpty)
    }

    @Test func matchesAreSortedByPosition() {
        let text = "item one apples item two oranges item three bananas"
        let matches = ListMarkerMatcher.findMarkers(in: text)
        for i in 0..<(matches.count - 1) {
            #expect(matches[i].range.lowerBound < matches[i + 1].range.lowerBound)
        }
    }

    @Test func isNarrativeOrdinalDetectsArticlePrecedingOrdinal() {
        let result = ListMarkerMatcher.isNarrativeOrdinal(in: "the first time I saw it")
        #expect(result == true)
    }

    @Test func isNarrativeOrdinalReturnsFalseForListUse() {
        let result = ListMarkerMatcher.isNarrativeOrdinal(in: "first do this second do that")
        #expect(result == false)
    }

    @Test func detectsNewBulletMarker() {
        let matches = ListMarkerMatcher.findMarkers(in: "new bullet eggs next item milk")
        let bullets = matches.filter { $0.category == "bullet" }
        #expect(bullets.count >= 1)
    }

    @Test func markerTextPreservesOriginalCase() {
        let matches = ListMarkerMatcher.findMarkers(in: "Item One apples Item Two oranges")
        let numbered = matches.filter { $0.category == "numbered" }
        #expect(numbered.count == 2)
        #expect(numbered[0].markerText.hasPrefix("Item"))
    }
}
