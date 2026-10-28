import Foundation
import Observation

struct TimedValue: Equatable {
    let date: Date
    let value: Double
}

enum ReadingState: Equatable {
    case loading, available(Date), unavailable, failed

    var sampledAt: Date? {
        if case let .available(date) = self { date } else { nil }
    }

    func isStale(at now: Date, interval: TimeInterval) -> Bool {
        sampledAt.map { now.timeIntervalSince($0) > max(15, interval * 2) } ?? false
    }
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
    /// Load the sampled processes don't account for (`kernel_task` and processes that came and went), in percent of one core. Derived, not measured.
    private(set) var hiddenLoad: Double?
    private(set) var memory: MemoryReading?
    /// Memory in use in percent of physical memory, oldest first, covering `historyWindow`.
    private(set) var memoryHistory: [TimedValue] = []
    private(set) var appMemory: [AppMemory] = []
    /// Empty on fanless Macs and when the SMC can't be opened.
    private(set) var fans: [FanReading] = []
    /// Whole-system power in watts, from the SMC.
    private(set) var systemPower: Double?
    /// GPU power in watts, from IOReport; nil until its energy counter has moved.
    private(set) var gpuPower: Double?
    private(set) var temperatureState = ReadingState.loading
    private(set) var cpuState = ReadingState.loading
    private(set) var memoryState = ReadingState.loading
    private(set) var fanState = ReadingState.loading
    private(set) var processState = ReadingState.loading
    private(set) var appMemoryState = ReadingState.loading

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
            processEpoch += 1
            processTask?.cancel()
            processTask = nil
            processSampler.reset()
            processes = []
            hiddenLoad = nil
            processState = .loading
            if samplesProcesses { sampleProcesses() }
        }
    }

    /// Footprints cost a pass over every pid, so they are read only while a view asks for them.
    var samplesAppMemory = false {
        didSet {
            guard samplesAppMemory != oldValue, timer != nil else { return }
            appMemory = []
            appMemoryState = .loading
            if samplesAppMemory { sampleAppMemory(at: .now) }
        }
    }

    @ObservationIgnored private let reader = HIDTemperatureReader()
    @ObservationIgnored private let smc = SMCReader()
    @ObservationIgnored private let gpuReader = GPUPowerReader()
    @ObservationIgnored private var gpuMeter = GPUPowerMeter()
    @ObservationIgnored private let coreNames = CoreLayout.names(for: CoreLayout.read())
    @ObservationIgnored private let processSampler = ProcessSampler()
    @ObservationIgnored private var previousTicks: [CPUTicks]?
    /// Live monitors only; previews and snapshots never notify.
    @ObservationIgnored private var heatAlerts: HeatAlerts?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var processTask: Task<Void, Never>?
    /// Bumped whenever sampling starts or stops, so a snapshot from before the change is dropped.
    @ObservationIgnored private var processEpoch = 0

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
        hiddenLoad: Double? = nil,
        memory: MemoryReading? = nil,
        memoryHistory: [TimedValue] = [],
        appMemory: [AppMemory] = [],
        fans: [FanReading] = [],
        systemPower: Double? = nil,
        gpuPower: Double? = nil,
        sampledAt: Date? = nil,
        processState: ReadingState? = nil,
        appMemoryState: ReadingState? = nil,
        fanState: ReadingState? = nil
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
        self.memory = memory
        self.memoryHistory = memoryHistory
        self.appMemory = appMemory
        self.fans = fans
        self.systemPower = systemPower
        self.gpuPower = gpuPower
        let now = sampledAt ?? history.last?.date ?? loadHistory.last?.date ?? memoryHistory.last?.date ?? Date.now
        temperatureState = cpuTemperature == nil ? .unavailable : .available(now)
        cpuState = cpuLoad == nil ? .unavailable : .available(now)
        memoryState = memory == nil ? .unavailable : .available(now)
        self.fanState = fanState ?? .available(now)
        self.processState = processState ?? .available(now)
        self.appMemoryState = appMemoryState ?? .available(now)
    }

    init() {
        rate = UserDefaults.standard.string(forKey: Self.rateKey).flatMap(SampleRate.init(rawValue:)) ?? .six
        heatAlerts = HeatAlerts()
        refresh()
        schedule()
        #if DEBUG
        // Checks notification permission and delivery without heating the Mac.
        if CommandLine.arguments.contains("-heatAlertTest") { heatAlerts?.send(celsius: cpuTemperature, thermalState: thermalState) }
        #endif
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

    func refresh() {
        let now = Date.now
        sensors = TemperatureSensors.byName(TemperatureSensors.usable(reader?.read() ?? []))
        cpuTemperature = TemperatureSensors.cpuTemperature(from: sensors)
        temperatureState = cpuTemperature == nil ? .unavailable : .available(now)
        thermalState = ProcessInfo.processInfo.thermalState
        memory = MemoryStats.read()
        memoryState = memory == nil ? .failed : .available(now)
        heatAlerts?.observe(celsius: cpuTemperature, thermalState: thermalState)
        let fanReadings = smc?.fans()
        fans = fanReadings ?? []
        fanState = fanReadings == nil ? .unavailable : .available(now)
        systemPower = smc?.systemPower()
        gpuPower = gpuReader?.sample().flatMap { gpuMeter.watts($0) }
        updateCPU(ticks: CPULoad.sample(), at: now)
        if let cpuTemperature { history.append(TimedValue(date: now, value: cpuTemperature)) }
        if let memory { memoryHistory.append(TimedValue(date: now, value: memory.usedPercent)) }
        pruneHistory(at: now)
        if samplesAppMemory { sampleAppMemory(at: now) }
        if samplesProcesses { sampleProcesses() }
    }

    func updateCPU(ticks: [CPUTicks]?, at now: Date) {
        cpuLoad = nil
        coreLoads = []
        defer { previousTicks = ticks }
        guard let ticks, !ticks.isEmpty else { cpuState = .failed; return }
        guard let previousTicks, previousTicks.count == ticks.count else { cpuState = .loading; return }
        guard let usage = CPULoad.usage(from: previousTicks.reduce(.zero, +), to: ticks.reduce(.zero, +))
        else { cpuState = .failed; return }
        cpuLoad = usage
        cpuState = .available(now)
        let names = coreNames.count == ticks.count ? coreNames : CoreLayout.names(for: ticks.indices.map { CoreInfo(logicalID: $0, cluster: nil) })
        coreLoads = names.compactMap { core in
            guard core.logicalID < ticks.count,
                  let usage = CPULoad.usage(from: previousTicks[core.logicalID], to: ticks[core.logicalID])
            else { return nil }
            return CoreLoad(name: core.name, cluster: core.cluster, usage: usage)
        }
        loadHistory.append(TimedValue(date: now, value: usage * 100))
    }

    func pruneHistory(at now: Date) {
        history.removeAll { now.timeIntervalSince($0.date) > Self.historyWindow }
        loadHistory.removeAll { now.timeIntervalSince($0.date) > Self.historyWindow }
        memoryHistory.removeAll { now.timeIntervalSince($0.date) > Self.historyWindow }
    }

    private func sampleAppMemory(at now: Date) {
        guard let footprints = MemoryStats.appFootprints() else {
            appMemory = []
            appMemoryState = .failed
            return
        }
        appMemory = MemoryStats.ranked(footprints)
        appMemoryState = .available(now)
    }

    private func sampleProcesses() {
        guard processTask == nil else { return }
        let epoch = processEpoch
        processTask = Task { [weak self] in
            guard let self else { return }
            defer { if epoch == processEpoch { processTask = nil } }
            for attempt in 0..<2 {
                let snapshot = await Task.detached(priority: .utility) { ProcessSampler.snapshot() }.value
                guard !Task.isCancelled, epoch == processEpoch, samplesProcesses else { return }
                guard let snapshot else {
                    processSampler.reset()
                    processes = []
                    hiddenLoad = nil
                    processState = .failed
                    return
                }
                if let sample = processSampler.sample(snapshot) {
                    processes = sample.ranked
                    processState = .available(.now)
                    hiddenLoad = cpuLoad.map { Self.hiddenLoad(totalFraction: $0, cores: coreLoads.count, visibleTotal: sample.visibleTotal) }
                    return
                }
                processState = .loading
                if attempt == 0 {
                    do { try await Task.sleep(for: .seconds(1)) } catch { return }
                }
            }
        }
    }

    /// Whole-CPU load expressed in one-core percent, minus what visible processes used; never negative.
    nonisolated static func hiddenLoad(totalFraction: Double, cores: Int, visibleTotal: Double) -> Double {
        max(0, totalFraction * Double(cores) * 100 - visibleTotal)
    }

}
