import Foundation
import SQLite3

enum AnalyticsQueries {

    /// Fetch daily analytics for a time period.
    static func getDailyAnalytics(
        store: SQLiteStore,
        days: Int = 30
    ) throws -> [MCPDailyAnalytics] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let cutoffString = formatter.string(from: cutoffDate)

        return try store.query(
            """
            SELECT ZDATESTRING, ZTRANSCRIPTIONCOUNT, ZTOTALWORDS, ZTOTALDURATION
            FROM ZDAILYANALYTICS
            WHERE ZDATESTRING >= ?
            ORDER BY ZDATESTRING DESC
            """,
            bind: [cutoffString]
        ) { stmt in
            MCPDailyAnalytics(
                date: SQLiteStore.text(stmt, 0),
                transcriptionCount: SQLiteStore.int(stmt, 1),
                totalWords: SQLiteStore.int(stmt, 2),
                totalDuration: SQLiteStore.double(stmt, 3)
            )
        }
    }

    /// Fetch top apps by word count.
    static func getTopApps(
        store: SQLiteStore,
        limit: Int = 5
    ) throws -> [MCPAppUsage] {
        try store.query(
            """
            SELECT ZBUNDLEID, ZAPPNAME, ZTOTALTRANSCRIPTIONS, ZTOTALWORDS,
                   ZTOTALDURATION, ZLASTUSED
            FROM ZAPPUSAGERECORD
            ORDER BY ZTOTALWORDS DESC
            LIMIT ?
            """,
            bind: [limit]
        ) { stmt in
            MCPAppUsage(
                bundleID: SQLiteStore.text(stmt, 0),
                appName: SQLiteStore.text(stmt, 1),
                totalTranscriptions: SQLiteStore.int(stmt, 2),
                totalWords: SQLiteStore.int(stmt, 3),
                totalDuration: SQLiteStore.double(stmt, 4),
                lastUsed: coreDataDateToISO8601(SQLiteStore.double(stmt, 5))
            )
        }
    }

    /// Get summary stats (total words, sessions, duration, time saved).
    static func getSummary(store: SQLiteStore) throws -> MCPAnalyticsSummary {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -365, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let cutoffString = formatter.string(from: cutoffDate)

        let rows = try store.query(
            """
            SELECT COALESCE(SUM(ZTOTALWORDS), 0),
                   COALESCE(SUM(ZTRANSCRIPTIONCOUNT), 0),
                   COALESCE(SUM(ZTOTALDURATION), 0)
            FROM ZDAILYANALYTICS
            WHERE ZDATESTRING >= ?
            """,
            bind: [cutoffString]
        ) { stmt in
            (
                words: SQLiteStore.int(stmt, 0),
                sessions: SQLiteStore.int(stmt, 1),
                duration: SQLiteStore.double(stmt, 2)
            )
        }

        let row = rows.first ?? (words: 0, sessions: 0, duration: 0)
        return MCPAnalyticsSummary(
            totalWords: row.words,
            totalSessions: row.sessions,
            totalDuration: row.duration,
            estimatedTimeSaved: row.duration * 0.65
        )
    }
}
