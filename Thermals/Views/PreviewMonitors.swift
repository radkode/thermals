import SwiftUI

/// Synthetic readings for previews and snapshot renders; never shown to users.
@MainActor
enum PreviewMonitors {
    static func cool() -> Monitor { make(peak: 47, load: 0.18, state: .nominal, memoryUsed: 0.52, pressure: .normal) }
    static func hot() -> Monitor { make(peak: 93, load: 0.96, state: .serious, memoryUsed: 0.93, pressure: .critical) }
    static func noSensors() -> Monitor { Monitor(sensors: [], cpuLoad: 0.12, thermalState: .nominal, history: []) }

    private static func make(peak: Double, load: Double, state: ProcessInfo.ThermalState, memoryUsed: Double, pressure: MemoryPressure) -> Monitor {
        let names = ["PMU tdie6", "PMU tdie3", "PMU tdie9", "PMU tdie2", "PMU tdie5", "PMU tdev1", "SOC MTR Temp Sensor0", "NAND CH0 temp", "gas gauge battery"]
        let sensors = names.enumerated().map { index, name in
            SensorReading(id: index, name: name, celsius: peak - Double(index) * (peak > 80 ? 4.5 : 1.4))
        }
        let now = Date.now
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
        let coreLoads = (1...6).map { CoreLoad(name: "P\($0)", cluster: .performance, usage: min(1, load * (1.1 - Double($0) * 0.08))) }
            + (1...6).map { CoreLoad(name: "E\($0)", cluster: .efficiency, usage: min(1, load * (0.5 - Double($0) * 0.05))) }
        let processes = [("Xcode", 3.1), ("swift-frontend", 2.4), ("Google Chrome", 0.9), ("Music", 0.45), ("Slack", 0.2), ("Finder", 0.04)]
            .map { ProcessLoad(name: $0.0, percent: $0.1 * load * 100) }
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
        return Monitor(
            sensors: sensors,
            cpuLoad: load,
            thermalState: state,
            history: history,
            coreLoads: coreLoads,
            loadHistory: loadHistory,
            processes: processes,
            hiddenLoad: load * 12 * 100 * 0.35,
            memory: memory,
            memoryHistory: memoryHistory,
            appMemory: appMemory,
            fans: [(1, 1350.0, 5349.0), (2, 1458.0, 5777.0)].map { id, low, high in
                FanReading(id: id, rpm: low + (high - low) * (load > 0.5 ? 0.9 - Double(id) * 0.05 : 0.02), minimum: low, maximum: high)
            }
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
