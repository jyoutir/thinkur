import Foundation
import SwiftData
import os

enum SwiftDataContainerFactory {
    /// Creates a persistent ModelContainer at the given URL, falling back to in-memory on failure.
    /// Sets completeFileProtection on the store directory for at-rest encryption.
    static func create(
        name: String,
        schema: Schema,
        storeURL: URL
    ) -> ModelContainer {
        // Set file protection on the store's parent directory
        let storeDir = storeURL.deletingLastPathComponent()
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: storeDir.path(percentEncoded: false)
        )
        do {
            let config = ModelConfiguration(name, schema: schema, url: storeURL)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            Logger.app.error("Failed to create ModelContainer '\(name)': \(error)")
            return createInMemory(schema: schema)
        }
    }

    /// Creates an in-memory ModelContainer (for testing or as fallback).
    static func createInMemory(schema: Schema) -> ModelContainer {
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Cannot create even in-memory ModelContainer: \(error)")
        }
    }
}
