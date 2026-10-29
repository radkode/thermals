import Foundation
import Testing
@testable import Thermals

@MainActor @Suite(.serialized)
struct MonitorSamplingTests {
    @Test func refreshSuspendsAndConcurrentRequestsShareOneSample() async {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let source = ControlledSensors(sample: SensorSample(date: date, sensors: [SensorReading(id: 1, name: "PMU tdie1", celsius: 42)], fans: []))
        let monitor = Monitor(sensors: [], cpuLoad: nil, thermalState: .nominal, history: [], collect: { await source.read() })
        var entered = 0
        let requests = (0..<20).map { _ in
            Task { @MainActor in
                entered += 1
                await monitor.refresh()
            }
        }
        while entered < 20 { await Task.yield() }
        await source.waitUntilStarted()
        #expect(monitor.cpuTemperature == nil)
        #expect(await source.calls == 1)
        await source.release()
        for request in requests { await request.value }
        #expect(await source.calls == 1)
        #expect(monitor.cpuTemperature == 42)
        #expect(monitor.history == [TimedValue(date: date, value: 42)])
        #expect(monitor.temperatureState == .available(date))
        #expect(monitor.fanState == .available(date))
    }

    @Test func completedSamplesKeepSourceTimestampsAndClearFailures() async {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let memory = MemoryReading(total: 100, app: 40, wired: 10, compressed: 5, cached: 25, free: 20, swapUsed: 0, pressure: .normal)
        let source = ControlledSensors(sample: SensorSample(date: date, sensors: [SensorReading(id: 1, name: "PMU tdie1", celsius: 42)],
                                                           memory: memory, fans: [], ticks: [.zero]))
        await source.release()
        let monitor = Monitor(sensors: [], cpuLoad: nil, thermalState: .nominal, history: [], collect: { await source.read() })
        await monitor.refresh()
        #expect(monitor.cpuState == .loading)
        #expect(monitor.memoryState == .available(date))
        var next = await source.sample
        next = SensorSample(date: date.addingTimeInterval(6), sensors: next.sensors, memory: memory, fans: [],
                            ticks: [CPUTicks(user: 25, system: 0, idle: 75, nice: 0)])
        await source.set(next)
        await monitor.refresh()
        #expect(monitor.cpuLoad == 0.25)
        #expect(monitor.loadHistory.last?.date == next.date)
        await source.set(SensorSample(date: date.addingTimeInterval(12)))
        await monitor.refresh()
        #expect(monitor.temperatureState == .unavailable)
        #expect(monitor.memoryState == .failed)
        #expect(monitor.fanState == .unavailable)
        #expect(monitor.cpuState == .failed)
        #expect(monitor.cpuTemperature == nil && monitor.memory == nil && monitor.cpuLoad == nil)
        #expect(monitor.history.count == 2 && monitor.memoryHistory.count == 2 && monitor.loadHistory.count == 1)
        await source.set(SensorSample(date: date.addingTimeInterval(18), ticks: [CPUTicks(user: 30, system: 0, idle: 90, nice: 0)]))
        await monitor.refresh()
        #expect(monitor.cpuState == .loading)
    }

    @Test func sessionsAwaitTheirFreshBoundarySamples() async throws {
        let name = "Thermals.SamplingTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let source = SessionSensors()
        let monitor = Monitor(defaults: defaults, collect: { await source.read() })
        await monitor.startSession()
        let first = try #require(monitor.sessions.current)
        #expect(first.peak != nil)
        await monitor.stopSession()
        let last = try #require(monitor.sessions.last)
        #expect(monitor.sessions.current == nil)
        let temperature = await source.lastTemperature
        let date = await source.lastDate
        #expect(last.peak == temperature)
        #expect(last.endedAt == date)
        let data = try #require(defaults.data(forKey: ThermalSessions.storageKey))
        let saved = try JSONDecoder().decode(ThermalSessions.self, from: data)
        #expect(saved == monitor.sessions)
    }
}

private actor ControlledSensors {
    var sample: SensorSample
    private(set) var calls = 0
    private var blocked = true
    private var pending: CheckedContinuation<Void, Never>?
    private var started: CheckedContinuation<Void, Never>?

    init(sample: SensorSample) { self.sample = sample }
    func read() async -> SensorSample {
        calls += 1
        started?.resume()
        started = nil
        if blocked { await withCheckedContinuation { pending = $0 } }
        return sample
    }
    func waitUntilStarted() async {
        if calls == 0 { await withCheckedContinuation { started = $0 } }
    }
    func release() { blocked = false; pending?.resume(); pending = nil }
    func set(_ sample: SensorSample) { self.sample = sample }
}

private actor SessionSensors {
    private(set) var lastTemperature = 20.0
    private(set) var lastDate = Date.now
    func read() -> SensorSample {
        lastTemperature += 1
        lastDate = .now
        return SensorSample(date: lastDate, sensors: [SensorReading(id: 1, name: "PMU tdie1", celsius: lastTemperature)])
    }
}
