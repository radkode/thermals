import Foundation
import Testing
@testable import Thermals

@MainActor @Suite(.serialized)
struct AppMemorySamplingTests {
    @Test func reopeningWaitsForTheOldScanAndRejectsItsResult() async throws {
        let source = ControlledFootprints()
        let monitor = makeMonitor(source)
        monitor.samplesAppMemory = true
        try await eventually { await source.calls == 1 }
        #expect(monitor.appMemoryState == .loading)
        await monitor.refresh()
        await monitor.refresh()
        #expect(await source.calls == 1)
        monitor.samplesAppMemory = false
        monitor.samplesAppMemory = true
        #expect(await source.calls == 1)
        try await source.finish([AppMemory(name: "Old", bytes: 100)])
        try await eventually { await source.calls == 2 }
        #expect(monitor.appMemory.isEmpty)
        #expect(monitor.appMemoryState == .loading)
        let before = Date.now
        try await source.finish([AppMemory(name: "New", bytes: 200)])
        try await eventually { monitor.appMemoryState.sampledAt != nil }
        #expect(monitor.appMemory == [AppMemory(name: "New", bytes: 200)])
        #expect(try #require(monitor.appMemoryState.sampledAt) <= before)
        #expect(await source.maximumInFlight == 1)
    }

    @Test func closingDiscardsThePendingResultAndStopsFurtherScans() async throws {
        let source = ControlledFootprints()
        let monitor = makeMonitor(source)
        monitor.samplesAppMemory = true
        try await eventually { await source.calls == 1 }
        monitor.samplesAppMemory = false
        try await source.finish([AppMemory(name: "Late", bytes: 100)])
        await monitor.refresh()
        await monitor.refresh()
        #expect(monitor.appMemory.isEmpty)
        #expect(monitor.appMemoryState == .loading)
        #expect(await source.calls == 1)
    }

    @Test func failedScanClearsOldRowsAndSuccessfulRetryRecovers() async throws {
        let source = ControlledFootprints()
        let monitor = makeMonitor(source)
        monitor.samplesAppMemory = true
        try await eventually { await source.calls == 1 }
        try await source.finish([AppMemory(name: "Before", bytes: 100)])
        try await eventually { !monitor.appMemory.isEmpty }
        await monitor.refresh()
        try await eventually { await source.calls == 2 }
        try await source.finish(nil)
        try await eventually { monitor.appMemoryState == .failed }
        #expect(monitor.appMemory.isEmpty)
        await monitor.refresh()
        try await eventually { await source.calls == 3 }
        try await source.finish([])
        try await eventually { monitor.appMemoryState.sampledAt != nil }
        #expect(monitor.appMemory.isEmpty)
        monitor.samplesAppMemory = false
    }

    private func makeMonitor(_ source: ControlledFootprints) -> Monitor {
        Monitor(sensors: [], cpuLoad: nil, thermalState: .nominal, history: [],
                collect: { SensorSample(date: .now) }, collectAppMemory: { await source.read() })
    }

    private func eventually(_ condition: @MainActor () async -> Bool) async throws {
        for _ in 0..<1000 {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        #expect(await condition(), "Sampling transition did not complete")
    }
}

private actor ControlledFootprints {
    private(set) var calls = 0
    private(set) var maximumInFlight = 0
    private var pending: [CheckedContinuation<[AppMemory]?, Never>] = []

    func read() async -> [AppMemory]? {
        calls += 1
        return await withCheckedContinuation {
            pending.append($0)
            maximumInFlight = max(maximumInFlight, pending.count)
        }
    }
    func finish(_ apps: [AppMemory]?) throws {
        let request = try #require(pending.first)
        pending.removeFirst()
        request.resume(returning: apps)
    }
}
