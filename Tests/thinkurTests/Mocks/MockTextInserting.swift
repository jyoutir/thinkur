import Foundation
@testable import thinkur

final class MockTextInserting: TextInserting {
    var insertedTexts: [String] = []

    func insertText(_ text: String) {
        insertedTexts.append(text)
    }
}
