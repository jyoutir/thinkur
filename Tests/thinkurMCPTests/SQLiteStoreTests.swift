import Testing
import Foundation
@testable import thinkur_mcp

@Suite("SQLiteStore")
struct SQLiteStoreTests {

    @Test("Opens in-memory database")
    func openInMemory() throws {
        let store = try SQLiteStore(path: ":memory:")
        #expect(store.path == ":memory:")
    }

    @Test("Fails gracefully for nonexistent database")
    func openNonexistent() {
        #expect(throws: SQLiteError.self) {
            _ = try SQLiteStore(path: "/nonexistent/path/db.store")
        }
    }
}
