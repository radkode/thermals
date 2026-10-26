import Foundation
import Observation

struct TimedValue: Equatable {
    let date: Date
    let value: Double
}

@MainActor
@Observable
final class Monitor {
    /// How far back the LAST 3 MIN meters reach, whatever the sampling rate.
    static let historyWindow: TimeInterval = 180

    private(set) var cpuTemperature: Double?
    private(set) var cpuLoad: Double?
    private(set) var sensors: [SensorReading] = []
    private(set) var thermalState = ProcessInfo.processInfo.thermalState
    /// CPU temperature readings, oldest first, covering `historyWindow`.
    private(set) var history: [TimedValue] = []
    private(set) var coreLoads: [CoreLoad] = []
    /// Total CPU load in percent, oldest first, covering `historyWindow`.
    private(set) var loadHistory: [TimedValue] = []
    private(set) var processes: [ProcessLoad] = []
    /// Load the visible processes don't account for (system and other users), in percent of one core. Derived, not measured.
    private(set) var hiddenLoad: Double?
    private(set) var updatedAt = Date.now

    var rate = SampleRate.six {
        didSet {
            guard rate != oldValue else { return }
            UserDefaults.standard.set(rate.rawValue, forKey: Self.rateKey)
            if timer != nil { schedule() }
        }
    }
    static let rateKey = "sampleRate"

    /// Process sampling costs a pass over every pid, so it runs only while a view asks for it.
    var samplesProcesses = false {
        didSet {
            guard samplesProcesses != oldValue, timer != nil else { return }
            processSampler.reset()
            processes = []
            hiddenLoad = nil
            if samplesProcesses { _ = processSampler.sample() }
        }
    }

    @ObservationIgnored private let reader = HIDTemperatureReader()
    @ObservationIgnored private let coreNames = CoreLayout.names(for: CoreLayout.read())
    @ObservationIgnored private let processSampler = ProcessSampler()
    @ObservationIgnored private var previousTicks: [CPUTicks]?
    @ObservationIgnored private var timer: Timer?

    var menuBarLevel: HeatLevel? { HeatLevel.menuBar(celsius: cpuTemperature?.rounded(), thermalState: thermalState) }

    /// Fixed readings with no sampling, for previews and snapshots.
    init(
        sensors: [SensorReading],
        cpuLoad: Double?,
        thermalState: ProcessInfo.ThermalState,
        history: [TimedValue],
        coreLoads: [CoreLoad] = [],
        loadHistory: [TimedValue] = [],
        processes: [ProcessLoad] = [],
        hiddenLoad: Double? = nil
    ) {
        self.sensors = TemperatureSensors.byName(sensors)
        self.cpuTemperature = TemperatureSensors.cpuTemperature(from: self.sensors)
        self.cpuLoad = cpuLoad
        self.thermalState = thermalState
        self.history = history
        self.coreLoads = coreLoads
        self.loadHistory = loadHistory
        self.processes = processes
        self.hiddenLoad = hiddenLoad
    }

    init() {
        rate = UserDefaults.standard.string(forKey: Self.rateKey).flatMap(SampleRate.init(rawValue:)) ?? .six
        refresh()
        schedule()
        // Load needs two samples; take the second one quickly instead of a full interval later.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    private func schedule() {
        timer?.invalidate()
        let timer = Timer(timeInterval: rate.seconds, repeats: true) { [weak self] _ in
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

        let now = Date.now
        if let cpuTemperature { append(TimedValue(date: now, value: cpuTemperature), to: &history) }
        if let cpuLoad { append(TimedValue(date: now, value: cpuLoad * 100), to: &loadHistory) }
        if samplesProcesses {
            let sample = processSampler.sample()
            processes = sample.ranked
            hiddenLoad = cpuLoad.map { Self.hiddenLoad(totalFraction: $0, cores: coreLoads.count, visibleTotal: sample.visibleTotal) }
        }
    }

    /// Whole-CPU load expressed in one-core percent, minus what visible processes used; never negative.
    nonisolated static func hiddenLoad(totalFraction: Double, cores: Int, visibleTotal: Double) -> Double {
        max(0, totalFraction * Double(cores) * 100 - visibleTotal)
    }

    private func append(_ reading: TimedValue, to series: inout [TimedValue]) {
        series.append(reading)
        series.removeAll { reading.date.timeIntervalSince($0.date) > Self.historyWindow }
    }
}
