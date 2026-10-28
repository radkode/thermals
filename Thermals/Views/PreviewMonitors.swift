import SwiftUI

/// Synthetic readings for previews and snapshot renders; never shown to users.
@MainActor
enum PreviewMonitors {
    static func initialCPU() -> Monitor {
        let monitor = Monitor(sensors: [], cpuLoad: nil, thermalState: .nominal, history: [], processState: .loading)
        monitor.updateCPU(ticks: [.zero], at: referenceDate)
        return monitor
    }

    static func emptyProcesses() -> Monitor {
        Monitor(sensors: [], cpuLoad: 0, thermalState: .nominal, history: [], sampledAt: referenceDate)
    }

    static let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
    static func cool() -> Monitor { make(peak: 47, load: 0.18, state: .nominal, memoryUsed: 0.52, pressure: .normal) }
    static func hot() -> Monitor { make(peak: 93, load: 0.96, state: .serious, memoryUsed: 0.93, pressure: .critical) }
    static func noSensors() -> Monitor {
        Monitor(sensors: [], cpuLoad: nil, thermalState: .nominal, history: [], sampledAt: referenceDate, processState: .failed, appMemoryState: .failed, fanState: .unavailable)
    }

    static func lowTemperatureCritical() -> Monitor { make(peak: 45, load: 0.2, state: .critical, memoryUsed: 0.93, pressure: .normal) }

    static func missingTemperatureCritical() -> Monitor {
        Monitor(sensors: [], cpuLoad: 0.1, thermalState: .critical, history: [], sampledAt: referenceDate)
    }

    static func stale() -> Monitor {
        let old = referenceDate.addingTimeInterval(-240)
        return Monitor(sensors: [SensorReading(id: 0, name: "PMU tdie1", celsius: 60)], cpuLoad: 0.4, thermalState: .nominal, history: [TimedValue(date: old, value: 60)], sampledAt: old)
    }

    static func largeMachine() -> Monitor {
        let cores = (1...32).map { CoreLoad(name: "P\($0)", cluster: .performance, usage: 0.5) }
            + (1...16).map { CoreLoad(name: "E\($0)", cluster: .efficiency, usage: 0.5) }
        return Monitor(sensors: [SensorReading(id: 0, name: "An unknown sensor with a long name", celsius: 40)], cpuLoad: 0.5, thermalState: .nominal, history: [], coreLoads: cores,
                       processes: [ProcessLoad(name: "A long application name sharing prefix Alpha", percent: 250), ProcessLoad(name: "A long application name sharing prefix Beta", percent: 125)],
                       fans: [FanReading(id: 1, rpm: 10_000, minimum: 0, maximum: 20_000)],
                       dailyPeak: DailyPeak(celsius: 104, date: referenceDate.addingTimeInterval(-600), culprit: "swift-frontend-with-a-long-name"), sampledAt: referenceDate)
    }

    static func make(peak: Double, load: Double, state: ProcessInfo.ThermalState, memoryUsed: Double, pressure: MemoryPressure) -> Monitor {
        let names = ["PMU tdie6", "PMU tdie3", "PMU tdie9", "PMU tdie2", "PMU tdie5", "PMU tdev1", "SOC MTR Temp Sensor0", "NAND CH0 temp", "gas gauge battery"]
        let sensors = names.enumerated().map { index, name in
            SensorReading(id: index, name: name, celsius: peak - Double(index) * (peak > 80 ? 4.5 : 1.4))
        }
        let now = referenceDate
        let count = 30
        let step = Monitor.historyWindow / Double(count)
        let curve = (0..<count).map { index -> Double in
            let t = Double(index) / Double(count)
            return (1 - t) * (1 - t)
        }
        let dates = (0..<count).map { now.addingTimeInterval(Double($0 - count + 1) * step) }
        let history = (0..<count).map { index in
            TimedValue(date: dates[index], value: peak - 28 * curve[index] + 1.5 * sin(Double(index)))
        }
        let loadHistory = (0..<count).map { index in
            TimedValue(date: dates[index], value: max(0, min(100, load * 100 - 60 * load * curve[index] + 6 * sin(Double(index) * 1.7))))
        }
        let coreLoads = (1...6).map { CoreLoad(name: "P\($0)", cluster: .performance, usage: min(1, max(0, load + 0.015 * (3.5 - Double($0))))) }
            + (1...6).map { CoreLoad(name: "E\($0)", cluster: .efficiency, usage: min(1, max(0, load + 0.015 * (3.5 - Double($0))))) }
        let totalLoad = coreLoads.map(\.usage).reduce(0, +) / Double(coreLoads.count)
        let processes = [("Xcode", 3.1), ("swift-frontend", 2.4), ("Google Chrome", 0.9), ("Music", 0.45), ("Slack", 0.2), ("Finder", 0.04)]
            .map { ProcessLoad(name: $0.0, percent: $0.1 * totalLoad * 100) }
        let gigabyte = 1_073_741_824.0
        let total = UInt64(16 * gigabyte)
        let used = 16 * memoryUsed
        let memory = MemoryReading(
            total: total,
            app: UInt64(used * 0.62 * gigabyte),
            wired: UInt64(used * 0.22 * gigabyte),
            compressed: UInt64(used * 0.16 * gigabyte),
            cached: UInt64((16 - used) * 0.7 * gigabyte),
            free: UInt64((16 - used) * 0.3 * gigabyte),
            swapUsed: memoryUsed > 0.9 ? UInt64(6.2 * gigabyte) : 0,
            pressure: pressure
        )
        let memoryHistory = (0..<count).map { index in
            TimedValue(date: dates[index], value: memoryUsed * 100 - 9 * memoryUsed * curve[index] + 0.8 * sin(Double(index) * 0.9))
        }
        let appMemory = [("Xcode", 0.21), ("Google Chrome", 0.16), ("Simulator", 0.09), ("Slack", 0.05), ("Music", 0.02), ("Finder", 0.01)]
            .map { AppMemory(name: $0.0, bytes: UInt64($0.1 * memoryUsed * 1.6 * 16 * gigabyte)) }
        // Typed steps: older Swift compilers time out type-checking this inline in the Monitor call.
        let fanSpecs: [(id: Int, low: Double, high: Double)] = [(1, 1350, 5349), (2, 1458, 5777)]
        let fans: [FanReading] = fanSpecs.map { spec in
            let fraction: Double = load > 0.5 ? 0.9 - Double(spec.id) * 0.05 : 0.02
            return FanReading(id: spec.id, rpm: spec.low + (spec.high - spec.low) * fraction, minimum: spec.low, maximum: spec.high)
        }
        let hiddenLoad = max(0, totalLoad * 12 * 100 - processes.map(\.percent).reduce(0, +))
        return Monitor(
            sensors: sensors,
            cpuLoad: totalLoad,
            thermalState: state,
            history: history,
            coreLoads: coreLoads,
            loadHistory: loadHistory,
            processes: processes,
            hiddenLoad: hiddenLoad,
            memory: memory,
            memoryHistory: memoryHistory,
            appMemory: appMemory,
            fans: fans,
            systemPower: 6 + 52 * load,
            gpuPower: 1.5 + 21 * load,
            dailyPeak: DailyPeak(celsius: peak + 3, date: now.addingTimeInterval(-5_400), culprit: load > 0.5 ? "xcodebuild" : "Google Chrome")
        )
    }
}

#Preview("Heat, cool") { PopoverView(monitor: PreviewMonitors.cool(), pinnedBoard: .heat) }
#Preview("Heat, hot") { PopoverView(monitor: PreviewMonitors.hot(), pinnedBoard: .heat) }
#Preview("CPU, cool") { PopoverView(monitor: PreviewMonitors.cool(), pinnedBoard: .cpu) }
#Preview("CPU, hot") { PopoverView(monitor: PreviewMonitors.hot(), pinnedBoard: .cpu) }
#Preview("RAM, cool") { PopoverView(monitor: PreviewMonitors.cool(), pinnedBoard: .ram) }
#Preview("RAM, hot") { PopoverView(monitor: PreviewMonitors.hot(), pinnedBoard: .ram) }
#Preview("No sensors") { PopoverView(monitor: PreviewMonitors.noSensors(), pinnedBoard: .heat) }
#Preview("Update available") { PopoverView(monitor: PreviewMonitors.cool(), updater: Updater(previewing: "0.3.0"), pinnedBoard: .heat) }
