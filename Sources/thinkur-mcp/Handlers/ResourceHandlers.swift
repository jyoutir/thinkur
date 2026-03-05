import Foundation
import MCP
import os

enum ResourceHandlers {
    private static let logger = Logger(subsystem: "com.jyo.thinkur-mcp", category: "resources")

    static func register(on server: Server, dataDir: URL) async {
        await server.withMethodHandler(ListResources.self) { _ in
            .init(resources: [
                Resource(
                    name: "Recent Transcriptions",
                    uri: "thinkur://transcriptions/recent",
                    description: "The user's last 50 voice transcriptions with timestamps and app context",
                    mimeType: "application/json"
                ),
                Resource(
                    name: "Dictation Summary",
                    uri: "thinkur://analytics/summary",
                    description: "Total words, sessions, time saved, and usage stats for the past year",
                    mimeType: "application/json"
                ),
            ])
        }

        await server.withMethodHandler(ReadResource.self) { params in
            let analyticsPath = dataDir.appendingPathComponent("analytics.store").path

            switch params.uri {
            case "thinkur://transcriptions/recent":
                do {
                    let store = try SQLiteStore(path: analyticsPath)
                    let records = try TranscriptionQueries.getTranscriptions(
                        store: store, days: 7, limit: 50
                    )
                    return .init(contents: [
                        .text(encodeJSON(records), uri: params.uri, mimeType: "application/json")
                    ])
                } catch {
                    logger.error("Failed to read recent transcriptions: \(error)")
                    return .init(contents: [
                        .text("Error: \(error)", uri: params.uri)
                    ])
                }

            case "thinkur://analytics/summary":
                do {
                    let store = try SQLiteStore(path: analyticsPath)
                    let summary = try AnalyticsQueries.getSummary(store: store)
                    return .init(contents: [
                        .text(encodeJSON(summary), uri: params.uri, mimeType: "application/json")
                    ])
                } catch {
                    logger.error("Failed to read analytics summary: \(error)")
                    return .init(contents: [
                        .text("Error: \(error)", uri: params.uri)
                    ])
                }

            default:
                return .init(contents: [
                    .text("Unknown resource: \(params.uri)", uri: params.uri)
                ])
            }
        }
    }

}
