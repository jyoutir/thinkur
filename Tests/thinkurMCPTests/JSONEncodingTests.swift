import Testing
import Foundation
@testable import thinkur_mcp

@Suite("JSONEncoding")
struct JSONEncodingTests {
    @Test func encodesSimpleStruct() {
        struct Item: Codable { let name: String; let count: Int }
        let result = encodeJSON(Item(name: "apple", count: 3))
        #expect(result.contains("\"name\" : \"apple\""))
        #expect(result.contains("\"count\" : 3"))
    }

    @Test func encodesArray() {
        let result = encodeJSON([1, 2, 3])
        #expect(result.contains("1"))
        #expect(result.contains("3"))
    }

    @Test func encodesEmptyArray() {
        let result = encodeJSON([String]())
        #expect(result == "[\n\n]")
    }

    @Test func outputIsPrettyPrinted() {
        struct Item: Codable { let a: Int }
        let result = encodeJSON(Item(a: 1))
        #expect(result.contains("\n"))
    }

    @Test func outputHasSortedKeys() {
        struct Item: Codable { let z: Int; let a: Int }
        let result = encodeJSON(Item(z: 2, a: 1))
        let aIndex = result.range(of: "\"a\"")!.lowerBound
        let zIndex = result.range(of: "\"z\"")!.lowerBound
        #expect(aIndex < zIndex)
    }

    @Test func encodesNestedStructure() {
        struct Inner: Codable { let value: String }
        struct Outer: Codable { let inner: Inner }
        let result = encodeJSON(Outer(inner: Inner(value: "test")))
        #expect(result.contains("\"value\" : \"test\""))
    }
}
