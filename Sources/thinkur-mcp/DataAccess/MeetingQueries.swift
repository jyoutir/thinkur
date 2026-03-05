import Foundation
import SQLite3
import os

private let logger = Logger(subsystem: "com.jyo.thinkur-mcp", category: "meetings")

/// Raw meeting row from SQLite, before segment attachment.
private typealias MeetingRow = (
    pk: Int,
    title: String,
    date: Double,
    duration: Double,
    speakerCount: Int,
    speakerNamesData: Data?
)

enum MeetingQueries {

    /// Fetch recent meetings with their segments.
    static func getMeetings(
        store: SQLiteStore,
        days: Int = 30,
        limit: Int = 20
    ) throws -> [MCPMeeting] {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400).timeIntervalSinceReferenceDate

        let rows = try store.query(
            """
            SELECT Z_PK, ZTITLE, ZDATE, ZDURATION, ZSPEAKERCOUNT, ZSPEAKERNAMESDATA
            FROM ZMEETINGRECORD
            WHERE ZDATE >= ?
            ORDER BY ZDATE DESC
            LIMIT ?
            """,
            bind: [cutoff, limit]
        ) { stmt -> MeetingRow in
            (
                pk: SQLiteStore.int(stmt, 0),
                title: SQLiteStore.text(stmt, 1),
                date: SQLiteStore.double(stmt, 2),
                duration: SQLiteStore.double(stmt, 3),
                speakerCount: SQLiteStore.int(stmt, 4),
                speakerNamesData: SQLiteStore.optionalBlob(stmt, 5)
            )
        }

        return try buildMeetings(from: rows, store: store)
    }

    /// Search meeting transcripts for a query.
    static func searchMeetings(
        store: SQLiteStore,
        query: String,
        days: Int = 30,
        limit: Int = 20
    ) throws -> [MCPMeeting] {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400).timeIntervalSinceReferenceDate
        let pattern = "%\(query)%"

        // Find meeting PKs that have matching segments
        let meetingPKs = try store.query(
            """
            SELECT DISTINCT ms.ZMEETING
            FROM ZMEETINGSEGMENT ms
            JOIN ZMEETINGRECORD mr ON mr.Z_PK = ms.ZMEETING
            WHERE mr.ZDATE >= ?
              AND ms.ZTEXT LIKE ?
            ORDER BY mr.ZDATE DESC
            LIMIT ?
            """,
            bind: [cutoff, pattern, limit]
        ) { stmt in
            SQLiteStore.int(stmt, 0)
        }

        guard !meetingPKs.isEmpty else { return [] }

        // Batch-fetch all matching meetings in one query
        let placeholders = meetingPKs.map { _ in "?" }.joined(separator: ",")
        let rows = try store.query(
            """
            SELECT Z_PK, ZTITLE, ZDATE, ZDURATION, ZSPEAKERCOUNT, ZSPEAKERNAMESDATA
            FROM ZMEETINGRECORD
            WHERE Z_PK IN (\(placeholders))
            ORDER BY ZDATE DESC
            """,
            bind: meetingPKs
        ) { stmt -> MeetingRow in
            (
                pk: SQLiteStore.int(stmt, 0),
                title: SQLiteStore.text(stmt, 1),
                date: SQLiteStore.double(stmt, 2),
                duration: SQLiteStore.double(stmt, 3),
                speakerCount: SQLiteStore.int(stmt, 4),
                speakerNamesData: SQLiteStore.optionalBlob(stmt, 5)
            )
        }

        return try buildMeetings(from: rows, store: store)
    }

    // MARK: - Private

    /// Batch-fetch segments for all meetings and assemble MCPMeeting objects.
    /// Runs exactly 1 additional query (segments) regardless of meeting count.
    private static func buildMeetings(from rows: [MeetingRow], store: SQLiteStore) throws -> [MCPMeeting] {
        guard !rows.isEmpty else { return [] }

        let pks = rows.map(\.pk)
        let placeholders = pks.map { _ in "?" }.joined(separator: ",")

        // Single query for ALL segments across all meetings
        let allSegments = try store.query(
            """
            SELECT ZMEETING, ZSPEAKERID, ZTEXT, ZSTARTTIME, ZENDTIME
            FROM ZMEETINGSEGMENT
            WHERE ZMEETING IN (\(placeholders))
            ORDER BY ZSTARTTIME ASC
            """,
            bind: pks
        ) { stmt in
            (
                meetingPK: SQLiteStore.int(stmt, 0),
                speakerId: SQLiteStore.text(stmt, 1),
                text: SQLiteStore.text(stmt, 2),
                startTime: SQLiteStore.double(stmt, 3),
                endTime: SQLiteStore.double(stmt, 4)
            )
        }

        // Group segments by meeting PK
        var segmentsByMeeting: [Int: [(speakerId: String, text: String, startTime: Double, endTime: Double)]] = [:]
        for seg in allSegments {
            segmentsByMeeting[seg.meetingPK, default: []].append(
                (speakerId: seg.speakerId, text: seg.text, startTime: seg.startTime, endTime: seg.endTime)
            )
        }

        return rows.map { meeting in
            let speakerNames = resolveSpeakerNames(meeting.speakerNamesData)
            let segments = (segmentsByMeeting[meeting.pk] ?? []).map { seg in
                MCPMeetingSegment(
                    speakerId: speakerNames[seg.speakerId] ?? defaultSpeakerName(seg.speakerId),
                    text: seg.text,
                    startTime: seg.startTime,
                    endTime: seg.endTime
                )
            }

            return MCPMeeting(
                title: meeting.title,
                date: coreDataDateToISO8601(meeting.date),
                duration: meeting.duration,
                speakerCount: meeting.speakerCount,
                segments: segments
            )
        }
    }

    /// Decode speaker name mapping from JSON blob, logging on failure.
    private static func resolveSpeakerNames(_ data: Data?) -> [String: String] {
        guard let data else { return [:] }
        do {
            return try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            logger.warning("Failed to decode speaker names: \(error)")
            return [:]
        }
    }

    private static func defaultSpeakerName(_ id: String) -> String {
        switch id {
        case "local": return "You"
        case _ where id.hasPrefix("remote-"):
            return "Speaker \(id.dropFirst("remote-".count))"
        case _ where id.hasPrefix("speaker-"):
            if let num = Int(id.dropFirst("speaker-".count)) {
                return "Speaker \(num + 1)"
            }
            return "Speaker"
        default:
            return "Speaker \(id)"
        }
    }
}
