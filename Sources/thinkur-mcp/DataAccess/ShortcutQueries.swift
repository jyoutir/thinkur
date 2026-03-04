import Foundation
import SQLite3

enum ShortcutQueries {

    /// Fetch all text expansion shortcuts.
    static func getShortcuts(store: SQLiteStore) throws -> [MCPShortcut] {
        try store.query(
            """
            SELECT ZTRIGGER, ZEXPANSION
            FROM ZSHORTCUT
            ORDER BY ZTRIGGER ASC
            """
        ) { stmt in
            MCPShortcut(
                trigger: SQLiteStore.text(stmt, 0),
                expansion: SQLiteStore.text(stmt, 1)
            )
        }
    }
}
