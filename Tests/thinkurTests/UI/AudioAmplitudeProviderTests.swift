import Testing
@testable import thinkur

@Suite("AudioAmplitudeProvider", .serialized)
struct AudioAmplitudeProviderTests {
    @Test @MainActor
    func pollingUpdatesAmplitudeBuffer() async {
        let level: Float = 1.0
        let provider = AudioAmplitudeProvider(bufferSize: 8, smoothingFactor: 1.0, pollingInterval: 0.01)

        provider.startPolling { level }
        try? await Task.sleep(for: .milliseconds(50))
        let hadNonZero = provider.amplitudes.contains(where: { $0 > 0.0 })
        provider.stopPolling()

        #expect(hadNonZero)
    }

    @Test @MainActor
    func stopPollingResetsProviderState() async {
        let level: Float = 0.8
        let provider = AudioAmplitudeProvider(bufferSize: 8, smoothingFactor: 1.0, pollingInterval: 0.01)

        provider.startPolling { level }
        try? await Task.sleep(for: .milliseconds(40))
        provider.stopPolling()

        #expect(provider.amplitudesStartIndex == 0)
        #expect(provider.amplitudes.allSatisfy { $0 == 0.0 })
    }

    @Test @MainActor
    func restartingPollingResetsRingIndexBeforeResuming() async {
        var counter: Float = 0
        let provider = AudioAmplitudeProvider(bufferSize: 8, smoothingFactor: 1.0, pollingInterval: 0.01)

        provider.startPolling {
            counter += 1
            return counter
        }
        // Allow enough RunLoop cycles for timer to fire (MainActor.assumeIsolated needs time)
        try? await Task.sleep(for: .milliseconds(100))
        #expect(provider.amplitudesStartIndex > 0)

        provider.startPolling {
            counter += 1
            return counter
        }
        #expect(provider.amplitudesStartIndex == 0)
        try? await Task.sleep(for: .milliseconds(30))
        let resumed = provider.amplitudes.contains(where: { $0 > 0.0 })
        provider.stopPolling()

        #expect(resumed)
    }
}
