import Foundation
import MCP
import os

enum ToolHandlers {
    private static let logger = Logger(subsystem: "com.jyo.thinkur-mcp", category: "tools")

    static func register(on server: Server, dataDir: URL) async {
        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: allTools)
        }

        await server.withMethodHandler(CallTool.self) { params in
            do {
                return try handleToolCall(params: params, dataDir: dataDir)
            } catch {
                logger.error("Tool '\(params.name)' failed: \(error)")
                return .init(content: [.text("Error: \(error)")], isError: true)
            }
        }
    }

    // MARK: - Tool Definitions

    private static let allTools: [Tool] = [
        Tool(
            name: "search_transcriptions",
            description: """
                Search the user's voice-to-text dictation history for a keyword or phrase. \
                thinkur is a macOS voice dictation app — every time the user speaks to type into any app, \
                the transcribed text is saved with a timestamp, the target app name, and duration. \
                This tool searches across all saved transcriptions (case-insensitive, partial match). \
                Use this when the user asks about a specific topic, phrase, or keyword from their past dictations. \
                Returns: processedText, rawText, timestamp (ISO 8601), appName, appBundleID, duration, wordCount, correctionCount. \
                Prefer this over get_transcriptions when the user wants to find something specific.
                """,
            inputSchema: [
                "type": "object",
                "properties": [
                    "query": ["type": "string", "description": "Keyword or phrase to search for (case-insensitive, partial match)"],
                    "days": ["type": "integer", "description": "How many days back to search (default: 30). Use 365 for a full year."],
                    "app": ["type": "string", "description": "Filter to a specific app by name (e.g. 'Slack', 'Notes', 'Safari') or macOS bundle ID"],
                    "limit": ["type": "integer", "description": "Maximum results to return (default: 50)"],
                ],
                "required": ["query"],
            ],
            annotations: .init(readOnlyHint: true, openWorldHint: false)
        ),

        Tool(
            name: "get_transcriptions",
            description: """
                Fetch the user's recent voice dictations, optionally filtered by app. \
                Each transcription represents one dictation session — the user pressed a hotkey, spoke, \
                and thinkur transcribed their speech and pasted it into the active app. \
                Use this when the user asks "what did I dictate today/this week?" or wants to review recent activity. \
                Returns an array sorted newest-first, each with: processedText (final text after corrections), \
                rawText (original transcription), timestamp (ISO 8601), appName, appBundleID, duration (seconds), \
                wordCount, correctionCount. \
                For keyword searches, prefer search_transcriptions instead.
                """,
            inputSchema: [
                "type": "object",
                "properties": [
                    "days": ["type": "integer", "description": "How many days back to fetch (default: 7). Use 1 for today only."],
                    "limit": ["type": "integer", "description": "Maximum results (default: 50). Use higher values for comprehensive analysis."],
                    "app": ["type": "string", "description": "Filter to a specific app by name (e.g. 'Notion', 'Slack') or macOS bundle ID"],
                ],
            ],
            annotations: .init(readOnlyHint: true, openWorldHint: false)
        ),

        Tool(
            name: "get_sessions",
            description: """
                Group consecutive dictations into conversation sessions. \
                When a user dictates multiple times into the same app within a few minutes, those dictations \
                are part of one logical session (e.g. writing an email, having a chat conversation, taking notes). \
                This tool merges them into coherent sessions with combined text. \
                Use this when the user asks to "summarize what I was working on" or wants to understand \
                their activity in terms of conversations rather than individual snippets. \
                Returns: appName, appBundleID, startTime, endTime (ISO 8601), totalDuration, totalWords, \
                transcriptionCount, combinedText (all dictations merged). Sorted newest-first. \
                For formal meetings with speaker labels, use get_meetings instead.
                """,
            inputSchema: [
                "type": "object",
                "properties": [
                    "days": ["type": "integer", "description": "How many days back (default: 7)"],
                    "app": ["type": "string", "description": "Filter to a specific app by name or bundle ID"],
                    "gap_minutes": ["type": "integer", "description": "Max minutes between dictations to consider them one session (default: 5). Increase for sparse dictation patterns."],
                ],
            ],
            annotations: .init(readOnlyHint: true, openWorldHint: false)
        ),

        Tool(
            name: "get_meetings",
            description: """
                Fetch recorded meetings with full speaker-diarized transcripts. \
                thinkur can record meetings (Zoom, Teams, Google Meet, etc.) and transcribe them with \
                speaker identification — showing who said what and when. \
                Each meeting has: title, date (ISO 8601), duration, speakerCount, and an array of segments. \
                Each segment has: speakerId (resolved to a name like "You" or "Speaker 1"), text, \
                startTime (seconds from meeting start), endTime. \
                Use this when the user asks about meetings, calls, or multi-person conversations. \
                For quick-dictation sessions (single-person, into apps), use get_sessions instead.
                """,
            inputSchema: [
                "type": "object",
                "properties": [
                    "days": ["type": "integer", "description": "How many days back to fetch meetings (default: 30)"],
                    "limit": ["type": "integer", "description": "Maximum meetings to return (default: 20)"],
                ],
            ],
            annotations: .init(readOnlyHint: true, openWorldHint: false)
        ),

        Tool(
            name: "search_meetings",
            description: """
                Search across all meeting transcripts for a keyword or topic. \
                Returns full meetings where any speaker's segment matches the query, \
                including all segments (not just matching ones) for full context. \
                Use this when the user asks "did anyone mention X in a meeting?" or \
                "what was said about Y in my calls?" \
                Returns the same structure as get_meetings but filtered to meetings containing the query.
                """,
            inputSchema: [
                "type": "object",
                "properties": [
                    "query": ["type": "string", "description": "Keyword or phrase to search for in meeting transcripts"],
                    "days": ["type": "integer", "description": "How many days back to search (default: 30)"],
                    "limit": ["type": "integer", "description": "Maximum meetings to return (default: 20)"],
                ],
                "required": ["query"],
            ],
            annotations: .init(readOnlyHint: true, openWorldHint: false)
        ),

        Tool(
            name: "get_analytics",
            description: """
                Get the user's dictation usage statistics broken down by day. \
                Shows how much the user has been dictating over time — useful for tracking habits, \
                productivity, or answering "how much did I dictate this week/month?" \
                Returns an array of daily entries, each with: date (yyyy-MM-dd), transcriptionCount, \
                totalWords, totalDuration (seconds). Sorted newest-first.
                """,
            inputSchema: [
                "type": "object",
                "properties": [
                    "period": ["type": "string", "description": "Time window: '7d' (last week), '30d' (last month), or '90d' (last quarter). Default: '30d'"],
                ],
            ],
            annotations: .init(readOnlyHint: true, openWorldHint: false)
        ),

        Tool(
            name: "get_top_apps",
            description: """
                Get which apps the user dictates into most, ranked by total words. \
                Shows the user's dictation habits across apps — useful for understanding workflow patterns. \
                Returns: appName, bundleID, totalTranscriptions, totalWords, totalDuration, lastUsed (ISO 8601).
                """,
            inputSchema: [
                "type": "object",
                "properties": [
                    "limit": ["type": "integer", "description": "Number of top apps to return (default: 5)"],
                ],
            ],
            annotations: .init(readOnlyHint: true, openWorldHint: false)
        ),

        Tool(
            name: "export_transcriptions",
            description: """
                Bulk export the user's dictation history in a structured format. \
                Use 'json' for programmatic processing, 'csv' for spreadsheets, or 'text' for \
                human-readable output. This tool returns larger payloads than get_transcriptions \
                (up to 10,000 records) — use it when the user wants to transfer data to another tool \
                (e.g. Obsidian, a spreadsheet), create a comprehensive report, or do deep analysis \
                across a long time period. Text format outputs as: [timestamp] (appName) transcription.
                """,
            inputSchema: [
                "type": "object",
                "properties": [
                    "days": ["type": "integer", "description": "How many days back to export (default: 30). Use 365 for a full year."],
                    "format": ["type": "string", "description": "'json' (structured, default), 'csv' (spreadsheet-ready), or 'text' (human-readable)"],
                ],
            ],
            annotations: .init(readOnlyHint: true, openWorldHint: false)
        ),

        Tool(
            name: "get_shortcuts",
            description: """
                List the user's text expansion shortcuts. \
                thinkur supports voice shortcuts — when the user says a trigger phrase while dictating, \
                it expands to the full text. For example, saying "my email" might expand to their email address. \
                Returns: trigger (the spoken phrase) and expansion (the replacement text).
                """,
            inputSchema: [
                "type": "object",
                "properties": [:],
            ],
            annotations: .init(readOnlyHint: true, openWorldHint: false)
        ),
    ]

    // MARK: - Tool Dispatch

    private static func handleToolCall(params: CallTool.Parameters, dataDir: URL) throws -> CallTool.Result {
        let args = params.arguments ?? [:]
        let analyticsPath = dataDir.appendingPathComponent("analytics.store").path
        let shortcutsPath = dataDir.appendingPathComponent("shortcuts.store").path
        let meetingsPath = dataDir.appendingPathComponent("meetings.store").path

        switch params.name {

        case "search_transcriptions":
            guard let query = args["query"]?.stringValue, !query.isEmpty else {
                return .init(content: [.text("Error: 'query' parameter is required")], isError: true)
            }
            let store = try SQLiteStore(path: analyticsPath)
            let results = try TranscriptionQueries.searchTranscriptions(
                store: store,
                query: query,
                days: clampedInt(args["days"], default: 30, in: 1...365),
                limit: clampedInt(args["limit"], default: 50, in: 1...10_000),
                app: args["app"]?.stringValue
            )
            return .init(content: [.text(encodeJSON(results))])

        case "get_transcriptions":
            let store = try SQLiteStore(path: analyticsPath)
            let results = try TranscriptionQueries.getTranscriptions(
                store: store,
                days: clampedInt(args["days"], default: 7, in: 1...365),
                limit: clampedInt(args["limit"], default: 50, in: 1...10_000),
                app: args["app"]?.stringValue
            )
            return .init(content: [.text(encodeJSON(results))])

        case "get_sessions":
            let store = try SQLiteStore(path: analyticsPath)
            let results = try TranscriptionQueries.getSessions(
                store: store,
                days: clampedInt(args["days"], default: 7, in: 1...365),
                gapMinutes: clampedInt(args["gap_minutes"], default: 5, in: 1...120),
                app: args["app"]?.stringValue
            )
            return .init(content: [.text(encodeJSON(results))])

        case "get_meetings":
            let store = try SQLiteStore(path: meetingsPath)
            let results = try MeetingQueries.getMeetings(
                store: store,
                days: clampedInt(args["days"], default: 30, in: 1...365),
                limit: clampedInt(args["limit"], default: 20, in: 1...10_000)
            )
            return .init(content: [.text(encodeJSON(results))])

        case "search_meetings":
            guard let query = args["query"]?.stringValue, !query.isEmpty else {
                return .init(content: [.text("Error: 'query' parameter is required")], isError: true)
            }
            let store = try SQLiteStore(path: meetingsPath)
            let results = try MeetingQueries.searchMeetings(
                store: store,
                query: query,
                days: clampedInt(args["days"], default: 30, in: 1...365),
                limit: clampedInt(args["limit"], default: 20, in: 1...10_000)
            )
            return .init(content: [.text(encodeJSON(results))])

        case "get_analytics":
            let store = try SQLiteStore(path: analyticsPath)
            let period = args["period"]?.stringValue ?? "30d"
            let days: Int
            switch period {
            case "7d": days = 7
            case "90d": days = 90
            default: days = 30
            }
            let results = try AnalyticsQueries.getDailyAnalytics(store: store, days: days)
            return .init(content: [.text(encodeJSON(results))])

        case "get_top_apps":
            let store = try SQLiteStore(path: analyticsPath)
            let results = try AnalyticsQueries.getTopApps(
                store: store,
                limit: clampedInt(args["limit"], default: 5, in: 1...10_000)
            )
            return .init(content: [.text(encodeJSON(results))])

        case "export_transcriptions":
            let store = try SQLiteStore(path: analyticsPath)
            let result = try TranscriptionQueries.exportTranscriptions(
                store: store,
                days: clampedInt(args["days"], default: 30, in: 1...365),
                format: args["format"]?.stringValue ?? "json"
            )
            return .init(content: [.text(result)])

        case "get_shortcuts":
            let store = try SQLiteStore(path: shortcutsPath)
            let results = try ShortcutQueries.getShortcuts(store: store)
            return .init(content: [.text(encodeJSON(results))])

        default:
            return .init(content: [.text("Unknown tool: \(params.name)")], isError: true)
        }
    }

    // MARK: - Helpers

    /// Extract Int from a Value, handling both .int and .double cases.
    private static func intArg(_ value: Value?) -> Int? {
        guard let value else { return nil }
        return Int(value, strict: false)
    }

    /// Extract and clamp an Int parameter to a safe range.
    private static func clampedInt(_ value: Value?, default defaultValue: Int, in range: ClosedRange<Int>) -> Int {
        guard let raw = intArg(value) else { return defaultValue }
        return min(max(raw, range.lowerBound), range.upperBound)
    }

}
