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
        let history = (0..<Monitor.historyLength).map { step in
            let t = Double(step) / Double(Monitor.historyLength)
            return TemperatureSample(date: now.addingTimeInterval(Double(step - Monitor.historyLength) * Monitor.interval), celsius: peak - 28 * (1 - t) * (1 - t) + 1.5 * sin(Double(step) / 3))
        }
        return Monitor(sensors: sensors, cpuLoad: load, thermalState: state, history: history)
    }
}

#Preview("Cool") { PopoverView(monitor: PreviewMonitors.cool()) }
#Preview("Hot") { PopoverView(monitor: PreviewMonitors.hot()) }
#Preview("No sensors") { PopoverView(monitor: PreviewMonitors.noSensors()) }
