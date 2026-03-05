import Foundation
import SQLite3

private struct SessionRow {
    let text: String
    let duration: Double
    let timestamp: Double
    let bundleID: String
    let appName: String
    let wordCount: Int
}

enum TranscriptionQueries {

    /// Fetch recent transcriptions with optional filters.
    static func getTranscriptions(
        store: SQLiteStore,
        days: Int = 7,
        limit: Int = 50,
        app: String? = nil
    ) throws -> [MCPTranscription] {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400).timeIntervalSinceReferenceDate
        var sql = """
            SELECT ZRAWTEXT, ZPROCESSEDTEXT, ZDURATION, ZTIMESTAMP,
                   ZAPPBUNDLEID, ZAPPNAME, ZWORDCOUNT, ZCORRECTIONCOUNT
            FROM ZTRANSCRIPTIONRECORD
            WHERE ZTIMESTAMP >= ?
            """
        var binds: [Any] = [cutoff]

        if let app {
            sql += " AND (ZAPPNAME LIKE ? OR ZAPPBUNDLEID LIKE ?)"
            binds.append("%\(app)%")
            binds.append("%\(app)%")
        }

        sql += " ORDER BY ZTIMESTAMP DESC LIMIT ?"
        binds.append(limit)

        return try store.query(sql, bind: binds) { stmt in
            MCPTranscription(
                rawText: SQLiteStore.text(stmt, 0),
                processedText: SQLiteStore.text(stmt, 1),
                duration: SQLiteStore.double(stmt, 2),
                timestamp: coreDataDateToISO8601(SQLiteStore.double(stmt, 3)),
                appBundleID: SQLiteStore.text(stmt, 4),
                appName: SQLiteStore.text(stmt, 5),
                wordCount: SQLiteStore.int(stmt, 6),
                correctionCount: SQLiteStore.int(stmt, 7)
            )
        }
    }

    /// Full-text search across transcriptions.
    static func searchTranscriptions(
        store: SQLiteStore,
        query: String,
        days: Int = 30,
        limit: Int = 50,
        app: String? = nil
    ) throws -> [MCPTranscription] {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400).timeIntervalSinceReferenceDate
        let pattern = "%\(query)%"
        var sql = """
            SELECT ZRAWTEXT, ZPROCESSEDTEXT, ZDURATION, ZTIMESTAMP,
                   ZAPPBUNDLEID, ZAPPNAME, ZWORDCOUNT, ZCORRECTIONCOUNT
            FROM ZTRANSCRIPTIONRECORD
            WHERE ZTIMESTAMP >= ?
              AND (ZPROCESSEDTEXT LIKE ? OR ZRAWTEXT LIKE ?)
            """
        var binds: [Any] = [cutoff, pattern, pattern]

        if let app {
            sql += " AND (ZAPPNAME LIKE ? OR ZAPPBUNDLEID LIKE ?)"
            binds.append("%\(app)%")
            binds.append("%\(app)%")
        }

        sql += " ORDER BY ZTIMESTAMP DESC LIMIT ?"
        binds.append(limit)

        return try store.query(sql, bind: binds) { stmt in
            MCPTranscription(
                rawText: SQLiteStore.text(stmt, 0),
                processedText: SQLiteStore.text(stmt, 1),
                duration: SQLiteStore.double(stmt, 2),
                timestamp: coreDataDateToISO8601(SQLiteStore.double(stmt, 3)),
                appBundleID: SQLiteStore.text(stmt, 4),
                appName: SQLiteStore.text(stmt, 5),
                wordCount: SQLiteStore.int(stmt, 6),
                correctionCount: SQLiteStore.int(stmt, 7)
            )
        }
    }

    /// Group consecutive transcriptions from the same app into sessions.
    static func getSessions(
        store: SQLiteStore,
        days: Int = 7,
        gapMinutes: Int = 5,
        app: String? = nil
    ) throws -> [MCPSession] {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400).timeIntervalSinceReferenceDate
        var sql = """
            SELECT ZPROCESSEDTEXT, ZDURATION, ZTIMESTAMP, ZAPPBUNDLEID, ZAPPNAME, ZWORDCOUNT
            FROM ZTRANSCRIPTIONRECORD
            WHERE ZTIMESTAMP >= ?
            """
        var binds: [Any] = [cutoff]

        if let app {
            sql += " AND (ZAPPNAME LIKE ? OR ZAPPBUNDLEID LIKE ?)"
            binds.append("%\(app)%")
            binds.append("%\(app)%")
        }

        sql += " ORDER BY ZTIMESTAMP ASC"

        let rows = try store.query(sql, bind: binds) { stmt in
            SessionRow(
                text: SQLiteStore.text(stmt, 0),
                duration: SQLiteStore.double(stmt, 1),
                timestamp: SQLiteStore.double(stmt, 2),
                bundleID: SQLiteStore.text(stmt, 3),
                appName: SQLiteStore.text(stmt, 4),
                wordCount: SQLiteStore.int(stmt, 5)
            )
        }

        guard !rows.isEmpty else { return [] }

        let gapSeconds = Double(gapMinutes) * 60
        var sessions: [MCPSession] = []
        var currentRows: [SessionRow] = [rows[0]]

        for i in 1..<rows.count {
            let prev = rows[i - 1]
            let curr = rows[i]
            let timeDiff = (curr.timestamp - prev.timestamp) - prev.duration

            if curr.bundleID == prev.bundleID && timeDiff <= gapSeconds {
                currentRows.append(curr)
            } else {
                sessions.append(buildSession(from: currentRows))
                currentRows = [curr]
            }
        }
        sessions.append(buildSession(from: currentRows))

        return sessions.reversed()
    }

    private static func buildSession(from rows: [SessionRow]) -> MCPSession {
        let first = rows[0]
        let last = rows[rows.count - 1]
        let totalWords = rows.reduce(0) { $0 + $1.wordCount }
        let totalDuration = rows.reduce(0.0) { $0 + $1.duration }
        let combinedText = rows.map(\.text).joined(separator: " ")

        return MCPSession(
            appName: first.appName,
            appBundleID: first.bundleID,
            startTime: coreDataDateToISO8601(first.timestamp),
            endTime: coreDataDateToISO8601(last.timestamp + last.duration),
            totalDuration: totalDuration,
            totalWords: totalWords,
            transcriptionCount: rows.count,
            combinedText: combinedText
        )
    }

    /// Export transcriptions in the requested format.
    static func exportTranscriptions(
        store: SQLiteStore,
        days: Int = 30,
        format: String = "json"
    ) throws -> String {
        let records = try getTranscriptions(store: store, days: days, limit: 10_000)

        switch format {
        case "csv":
            var csv = "timestamp,app_name,duration,word_count,processed_text\n"
            for r in records {
                let escaped = r.processedText.replacingOccurrences(of: "\"", with: "\"\"")
                csv += "\"\(r.timestamp)\",\"\(r.appName)\",\(r.duration),\(r.wordCount),\"\(escaped)\"\n"
            }
            return csv

        case "text":
            return records.map { "[\($0.timestamp)] (\($0.appName)) \($0.processedText)" }
                .joined(separator: "\n\n")

        default: // json
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(records)
            return String(data: data, encoding: .utf8) ?? "[]"
        }
    }
}
