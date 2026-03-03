import Testing
import Carbon
@testable import thinkur

@Suite("HotkeyManager")
struct HotkeyManagerTests {

    // MARK: - Lifecycle

    @Suite("Start/Stop Lifecycle")
    struct LifecycleTests {

        @Test @MainActor func initialState_notRunning() {
            let manager = HotkeyManager()
            #expect(!manager.isRunning)
        }

        @Test @MainActor func stop_whenNotRunning_isNoop() {
            let manager = HotkeyManager()
            manager.stop() // Should not crash
            #expect(!manager.isRunning)
        }

        @Test @MainActor func doubleStop_isNoop() {
            let manager = HotkeyManager()
            _ = manager.start()
            manager.stop()
            manager.stop() // Should not crash
            #expect(!manager.isRunning)
        }

        @Test @MainActor func start_setsRunning() {
            let manager = HotkeyManager()
            let result = manager.start()
            #expect(result)
            #expect(manager.isRunning)
            manager.stop()
        }

        @Test @MainActor func doubleStart_returnsTrue() {
            let manager = HotkeyManager()
            _ = manager.start()
            let result = manager.start()
            #expect(result, "Double start should return true (already running)")
            manager.stop()
        }

        @Test @MainActor func stop_clearsCallbacks() {
            let manager = HotkeyManager()
            manager.onKeyDown = {}
            manager.onKeyUp = {}
            _ = manager.start()
            manager.stop()
            #expect(manager.onKeyDown == nil)
            #expect(manager.onKeyUp == nil)
        }
    }

    // MARK: - Migration

    @Suite("HotkeyMigration")
    struct MigrationTests {

        @Test func convertsCGEventFlagsToCarbonModifiers_command() {
            let result = HotkeyMigration.convertToCarbonModifiers(.maskCommand)
            #expect(result == cmdKey)
        }

        @Test func convertsCGEventFlagsToCarbonModifiers_shift() {
            let result = HotkeyMigration.convertToCarbonModifiers(.maskShift)
            #expect(result == shiftKey)
        }

        @Test func convertsCGEventFlagsToCarbonModifiers_option() {
            let result = HotkeyMigration.convertToCarbonModifiers(.maskAlternate)
            #expect(result == optionKey)
        }

        @Test func convertsCGEventFlagsToCarbonModifiers_control() {
            let result = HotkeyMigration.convertToCarbonModifiers(.maskControl)
            #expect(result == controlKey)
        }

        @Test func convertsCGEventFlagsToCarbonModifiers_empty() {
            let result = HotkeyMigration.convertToCarbonModifiers([])
            #expect(result == 0)
        }

        @Test func convertsCGEventFlagsToCarbonModifiers_allFour() {
            let result = HotkeyMigration.convertToCarbonModifiers([
                .maskCommand, .maskShift, .maskAlternate, .maskControl
            ])
            let expected = cmdKey | shiftKey | optionKey | controlKey
            #expect(result == expected)
        }

        @Test func nonStandardFlags_ignored() {
            let result = HotkeyMigration.convertToCarbonModifiers(.maskSecondaryFn)
            #expect(result == 0)
        }

        @Test func migrateIfNeeded_setsFlag() {
            let defaults = UserDefaults(suiteName: "com.thinkur.test.\(UUID())")!
            defaults.set(48, forKey: "hotkeyCode") // Tab
            defaults.set(0, forKey: "hotkeyModifiers")

            HotkeyMigration.migrateIfNeeded(defaults: defaults)
            #expect(defaults.bool(forKey: "hotkeyMigratedToKeyboardShortcuts"))
        }

        @Test func migrateIfNeeded_skipsWhenAlreadyMigrated() {
            let defaults = UserDefaults(suiteName: "com.thinkur.test.\(UUID())")!
            defaults.set(true, forKey: "hotkeyMigratedToKeyboardShortcuts")
            defaults.set(48, forKey: "hotkeyCode")

            // Should be a no-op — no crash
            HotkeyMigration.migrateIfNeeded(defaults: defaults)
        }

        @Test func migrateIfNeeded_skipsFnGlobeKey() {
            let defaults = UserDefaults(suiteName: "com.thinkur.test.\(UUID())")!
            defaults.set(63, forKey: "hotkeyCode") // Fn/Globe
            defaults.set(0, forKey: "hotkeyModifiers")

            // Should skip without crash — Fn can't be registered with Carbon
            HotkeyMigration.migrateIfNeeded(defaults: defaults)
            #expect(defaults.bool(forKey: "hotkeyMigratedToKeyboardShortcuts"))
        }
    }
}
