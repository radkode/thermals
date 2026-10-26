import SwiftUI

/// Synthetic readings for previews and snapshot renders; never shown to users.
@MainActor
enum PreviewMonitors {
    static func cool() -> Monitor { make(peak: 47, load: 0.18, state: .nominal) }
    static func hot() -> Monitor { make(peak: 93, load: 0.96, state: .serious) }
    static func noSensors() -> Monitor { Monitor(sensors: [], cpuLoad: 0.12, thermalState: .nominal, history: []) }

    private static func make(peak: Double, load: Double, state: ProcessInfo.ThermalState) -> Monitor {
        let names = ["PMU tdie6", "PMU tdie3", "PMU tdie9", "PMU tdie2", "PMU tdie5", "PMU tdev1", "SOC MTR Temp Sensor0", "NAND CH0 temp", "gas gauge battery"]
        let sensors = names.enumerated().map { index, name in
            SensorReading(id: index, name: name, celsius: peak - Double(index) * (peak > 80 ? 4.5 : 1.4))
        }
        let now = Date.now
        let steps = 0..<Monitor.historyLength
        let curve = steps.map { step -> Double in
            let t = Double(step) / Double(Monitor.historyLength)
            return (1 - t) * (1 - t)
        }
        let history = steps.map { step in
            TemperatureSample(
                date: now.addingTimeInterval(Double(step - Monitor.historyLength) * Monitor.interval),
                celsius: peak - 28 * curve[step] + 1.5 * sin(Double(step) / 3)
            )
        }
        let loadHistory = steps.map { step in max(0, min(100, load * 100 - 60 * load * curve[step] + 6 * sin(Double(step) / 2))) }
        let coreLoads = (1...6).map { CoreLoad(name: "P\($0)", cluster: .performance, usage: min(1, load * (1.1 - Double($0) * 0.08))) }
            + (1...6).map { CoreLoad(name: "E\($0)", cluster: .efficiency, usage: min(1, load * (0.5 - Double($0) * 0.05))) }
        let processes = [("Xcode", 3.1), ("swift-frontend", 2.4), ("Google Chrome", 0.9), ("Music", 0.45), ("Slack", 0.2), ("Finder", 0.04)]
            .map { ProcessLoad(name: $0.0, percent: $0.1 * load * 100) }
        return Monitor(
            sensors: sensors,
            cpuLoad: load,
            thermalState: state,
            history: history,
            coreLoads: coreLoads,
            loadHistory: loadHistory,
            processes: processes,
            hiddenLoad: load * 12 * 100 * 0.35
        )
    }
}

#Preview("Heat, cool") { PopoverView(monitor: PreviewMonitors.cool(), pinnedBoard: .heat) }
#Preview("Heat, hot") { PopoverView(monitor: PreviewMonitors.hot(), pinnedBoard: .heat) }
#Preview("CPU, cool") { PopoverView(monitor: PreviewMonitors.cool(), pinnedBoard: .cpu) }
#Preview("CPU, hot") { PopoverView(monitor: PreviewMonitors.hot(), pinnedBoard: .cpu) }
#Preview("No sensors") { PopoverView(monitor: PreviewMonitors.noSensors(), pinnedBoard: .heat) }
