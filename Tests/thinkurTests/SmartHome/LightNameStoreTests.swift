import Testing
import Foundation
@testable import thinkur

@Suite("LightNameStore")
struct LightNameStoreTests {

    private func makeStore() -> (LightNameStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: "com.thinkur.test.\(UUID())")!
        let store = LightNameStore(defaults: defaults)
        return (store, defaults)
    }

    @Test("Store and retrieve custom name")
    @MainActor
    func storeAndRetrieve() {
        let (store, _) = makeStore()

        #expect(store.displayName(for: "light-1") == nil)

        store.setCustomName("Desk Light", for: "light-1")
        #expect(store.displayName(for: "light-1") == "Desk Light")
    }

    @Test("Remove custom name")
    @MainActor
    func removeCustomName() {
        let (store, _) = makeStore()

        store.setCustomName("Desk Light", for: "light-1")
        store.removeCustomName(for: "light-1")
        #expect(store.displayName(for: "light-1") == nil)
    }

    @Test("Apply custom names to lights array")
    @MainActor
    func applyCustomNames() {
        let (store, _) = makeStore()

        store.setCustomName("My Desk Light", for: "1")

        var lights = [
            SmartLight(id: "1", name: "Lamp", roomName: "Office", isOn: true, brightness: 80, isReachable: true, backend: .hue),
            SmartLight(id: "2", name: "Ceiling", roomName: "Office", isOn: false, brightness: 0, isReachable: true, backend: .hue),
        ]

        store.applyCustomNames(to: &lights)

        #expect(lights[0].name == "My Desk Light")
        #expect(lights[0].originalName == "Lamp")
        #expect(lights[1].name == "Ceiling") // unchanged
    }

    @Test("Custom names persist across store instances")
    @MainActor
    func persistence() {
        let defaults = UserDefaults(suiteName: "com.thinkur.test.\(UUID())")!

        let store1 = LightNameStore(defaults: defaults)
        store1.setCustomName("Living Room Lamp", for: "light-42")

        let store2 = LightNameStore(defaults: defaults)
        #expect(store2.displayName(for: "light-42") == "Living Room Lamp")
    }

    @Test("Multiple lights can have custom names")
    @MainActor
    func multipleNames() {
        let (store, _) = makeStore()

        store.setCustomName("Name A", for: "1")
        store.setCustomName("Name B", for: "2")
        store.setCustomName("Name C", for: "3")

        #expect(store.displayName(for: "1") == "Name A")
        #expect(store.displayName(for: "2") == "Name B")
        #expect(store.displayName(for: "3") == "Name C")
    }
}
