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

    @ObservationIgnored private let reader = HIDTemperatureReader()
    @ObservationIgnored private var previousTicks: CPUTicks?
    @ObservationIgnored private var timer: Timer?

    var menuBarBand: HeatBand? { HeatBand.menuBar(celsius: cpuTemperature, thermalState: thermalState) }
    private(set) var updatedAt = Date.now

    /// Fixed readings with no sampling, for previews and snapshots.
    init(sensors: [SensorReading], cpuLoad: Double?, thermalState: ProcessInfo.ThermalState, history: [TemperatureSample]) {
        self.sensors = TemperatureSensors.byName(sensors)
        self.cpuTemperature = TemperatureSensors.cpuTemperature(from: self.sensors)
        self.cpuLoad = cpuLoad
        self.thermalState = thermalState
        self.history = history
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
            if let previousTicks { cpuLoad = CPULoad.usage(from: previousTicks, to: ticks) }
            previousTicks = ticks
        }

        if let cpuTemperature {
            history.append(TemperatureSample(date: .now, celsius: cpuTemperature))
            if history.count > Self.historyLength { history.removeFirst(history.count - Self.historyLength) }
        }
    }
}
