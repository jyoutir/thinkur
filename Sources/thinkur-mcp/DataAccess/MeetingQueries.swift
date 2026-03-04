import Foundation
import SQLite3

enum MeetingQueries {

    /// Fetch recent meetings with their segments.
    static func getMeetings(
        store: SQLiteStore,
        days: Int = 30,
        limit: Int = 20
    ) throws -> [MCPMeeting] {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400).timeIntervalSinceReferenceDate

        // Fetch meetings
        let meetings = try store.query(
            """
            SELECT Z_PK, ZTITLE, ZDATE, ZDURATION, ZSPEAKERCOUNT, ZSPEAKERNAMESDATA
            FROM ZMEETINGRECORD
            WHERE ZDATE >= ?
            ORDER BY ZDATE DESC
            LIMIT ?
            """,
            bind: [cutoff, limit]
        ) { stmt in
            (
                pk: SQLiteStore.int(stmt, 0),
                title: SQLiteStore.text(stmt, 1),
                date: SQLiteStore.double(stmt, 2),
                duration: SQLiteStore.double(stmt, 3),
                speakerCount: SQLiteStore.int(stmt, 4),
                speakerNamesData: SQLiteStore.optionalBlob(stmt, 5)
            )
        }

        return try meetings.map { meeting in
            let segments = try store.query(
                """
                SELECT ZSPEAKERID, ZTEXT, ZSTARTTIME, ZENDTIME
                FROM ZMEETINGSEGMENT
                WHERE ZMEETING = ?
                ORDER BY ZSTARTTIME ASC
                """,
                bind: [meeting.pk]
            ) { stmt in
                MCPMeetingSegment(
                    speakerId: SQLiteStore.text(stmt, 0),
                    text: SQLiteStore.text(stmt, 1),
                    startTime: SQLiteStore.double(stmt, 2),
                    endTime: SQLiteStore.double(stmt, 3)
                )
            }

            // Resolve speaker names from JSON data
            var speakerNames: [String: String] = [:]
            if let data = meeting.speakerNamesData {
                speakerNames = (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
            }

            let resolvedSegments = segments.map { seg in
                let name = speakerNames[seg.speakerId] ?? defaultSpeakerName(seg.speakerId)
                return MCPMeetingSegment(
                    speakerId: name,
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
                segments: resolvedSegments
            )
        }
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

        // Find meetings that have segments matching the query
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

        // Fetch full meetings for matching PKs
        return try meetingPKs.compactMap { pk in
            let meetings = try store.query(
                """
                SELECT Z_PK, ZTITLE, ZDATE, ZDURATION, ZSPEAKERCOUNT, ZSPEAKERNAMESDATA
                FROM ZMEETINGRECORD
                WHERE Z_PK = ?
                """,
                bind: [pk]
            ) { stmt in
                (
                    pk: SQLiteStore.int(stmt, 0),
                    title: SQLiteStore.text(stmt, 1),
                    date: SQLiteStore.double(stmt, 2),
                    duration: SQLiteStore.double(stmt, 3),
                    speakerCount: SQLiteStore.int(stmt, 4),
                    speakerNamesData: SQLiteStore.optionalBlob(stmt, 5)
                )
            }

            guard let meeting = meetings.first else { return nil }

            let segments = try store.query(
                """
                SELECT ZSPEAKERID, ZTEXT, ZSTARTTIME, ZENDTIME
                FROM ZMEETINGSEGMENT
                WHERE ZMEETING = ?
                ORDER BY ZSTARTTIME ASC
                """,
                bind: [pk]
            ) { stmt in
                MCPMeetingSegment(
                    speakerId: SQLiteStore.text(stmt, 0),
                    text: SQLiteStore.text(stmt, 1),
                    startTime: SQLiteStore.double(stmt, 2),
                    endTime: SQLiteStore.double(stmt, 3)
                )
            }

            var speakerNames: [String: String] = [:]
            if let data = meeting.speakerNamesData {
                speakerNames = (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
            }

            let resolvedSegments = segments.map { seg in
                let name = speakerNames[seg.speakerId] ?? defaultSpeakerName(seg.speakerId)
                return MCPMeetingSegment(
                    speakerId: name,
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
                segments: resolvedSegments
            )
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
