import Foundation
import MCP
import os

@main
struct ThinkurMCP {
    static let logger = Logger(subsystem: "com.jyo.thinkur-mcp", category: "server")

    static func main() async throws {
        logger.info("thinkur-mcp starting")

        let server = Server(
            name: "thinkur",
            version: "1.0.0",
            capabilities: .init(
                resources: .init(listChanged: false),
                tools: .init(listChanged: false)
            )
        )

        let dataDir = Self.resolveDataDirectory()
        logger.info("Data directory: \(dataDir.path)")

        // Register handlers
        await ToolHandlers.register(on: server, dataDir: dataDir)
        await ResourceHandlers.register(on: server, dataDir: dataDir)

        // Start with stdio transport
        let transport = StdioTransport()
        try await server.start(transport: transport)
        logger.info("thinkur-mcp server running")
        await server.waitUntilCompleted()
    }

    /// Resolve the thinkur data directory.
    /// Supports THINKUR_DATA_DIR env var override for non-standard installs.
    static func resolveDataDirectory() -> URL {
        if let override = ProcessInfo.processInfo.environment["THINKUR_DATA_DIR"] {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("thinkur", isDirectory: true)
    }
}
