import Foundation
import Observation

struct TemperatureSample: Identifiable {
    let date: Date
    let celsius: Double
    var id: Date { date }
}

@MainActor
@Observable
final class Monitor {
    static let interval: TimeInterval = 2
    static let historyLength = 90

    private(set) var cpuTemperature: Double?
    private(set) var cpuLoad: Double?
    private(set) var sensors: [SensorReading] = []
    private(set) var thermalState = ProcessInfo.processInfo.thermalState
    private(set) var history: [TemperatureSample] = []
    private(set) var coreLoads: [CoreLoad] = []
    /// Total CPU load in percent, oldest first.
    private(set) var loadHistory: [Double] = []
    private(set) var processes: [ProcessLoad] = []
    private(set) var updatedAt = Date.now

    /// Process sampling costs a pass over every pid, so it runs only while a view asks for it.
    var samplesProcesses = false {
        didSet {
            guard samplesProcesses != oldValue, timer != nil else { return }
            processSampler.reset()
            processes = []
            if samplesProcesses { _ = processSampler.sample() }
        }
    }

    @ObservationIgnored private let reader = HIDTemperatureReader()
    @ObservationIgnored private let coreNames = CoreLayout.names(for: CoreLayout.read())
    @ObservationIgnored private let processSampler = ProcessSampler()
    @ObservationIgnored private var previousTicks: [CPUTicks]?
    @ObservationIgnored private var timer: Timer?

    var menuBarBand: HeatBand? { HeatBand.menuBar(celsius: cpuTemperature, thermalState: thermalState) }

    /// Fixed readings with no sampling, for previews and snapshots.
    init(
        sensors: [SensorReading],
        cpuLoad: Double?,
        thermalState: ProcessInfo.ThermalState,
        history: [TemperatureSample],
        coreLoads: [CoreLoad] = [],
        loadHistory: [Double] = [],
        processes: [ProcessLoad] = []
    ) {
        self.sensors = TemperatureSensors.byName(sensors)
        self.cpuTemperature = TemperatureSensors.cpuTemperature(from: self.sensors)
        self.cpuLoad = cpuLoad
        self.thermalState = thermalState
        self.history = history
        self.coreLoads = coreLoads
        self.loadHistory = loadHistory
        self.processes = processes
    }

    init() {
        refresh()
        let timer = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func refresh() {
        sensors = TemperatureSensors.byName(TemperatureSensors.usable(reader?.read() ?? []))
        cpuTemperature = TemperatureSensors.cpuTemperature(from: sensors)
        thermalState = ProcessInfo.processInfo.thermalState
        updatedAt = .now

        if let ticks = CPULoad.sample() {
            if let previousTicks, previousTicks.count == ticks.count {
                cpuLoad = CPULoad.usage(from: previousTicks.reduce(.zero, +), to: ticks.reduce(.zero, +))
                let names = coreNames.isEmpty
                    ? CoreLayout.names(for: ticks.indices.map { CoreInfo(logicalID: $0, cluster: nil) })
                    : coreNames
                coreLoads = names.compactMap { core in
                    guard core.logicalID < ticks.count,
                          let usage = CPULoad.usage(from: previousTicks[core.logicalID], to: ticks[core.logicalID])
                    else { return nil }
                    return CoreLoad(name: core.name, cluster: core.cluster, usage: usage)
                }
            }
            previousTicks = ticks
        }

        if let cpuTemperature { append(TemperatureSample(date: .now, celsius: cpuTemperature), to: &history) }
        if let cpuLoad { append(cpuLoad * 100, to: &loadHistory) }
        if samplesProcesses { processes = processSampler.sample() }
    }

    private func append<T>(_ value: T, to series: inout [T]) {
        series.append(value)
        if series.count > Self.historyLength { series.removeFirst(series.count - Self.historyLength) }
    }
}
