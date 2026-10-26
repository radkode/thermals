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

    var sensorsAvailable: Bool { reader != nil && !sensors.isEmpty }

    init() {
        refresh()
        let timer = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func refresh() {
        sensors = TemperatureSensors.usable(reader?.read() ?? [])
            .sorted { $0.celsius > $1.celsius }
        cpuTemperature = TemperatureSensors.cpuTemperature(from: sensors)
        thermalState = ProcessInfo.processInfo.thermalState

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
