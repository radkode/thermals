import Foundation
import Darwin

@main struct SensorBench {
    static func cpuMS(_ who: Int32 = RUSAGE_SELF) -> Double {
        var usage = rusage()
        getrusage(who, &usage)
        return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) * 1000
            + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1000
    }

    static func main() throws {
        var results: [[String: Any]] = []
        func bench<T>(_ name: String, count: Int = 100, gap: Double = 0.01, _ operation: () -> T) {
            var wall: [Double] = []
            let cpu = cpuMS(), child = cpuMS(RUSAGE_CHILDREN)
            for _ in 0..<count {
                let start = DispatchTime.now().uptimeNanoseconds
                autoreleasepool { withExtendedLifetime(operation()) {} }
                wall.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6)
                Thread.sleep(forTimeInterval: gap)
            }
            let sorted = wall.sorted()
            results.append(["name": name, "n": count, "wall_ms": wall,
                "median_ms": sorted[count / 2], "p95_ms": sorted[Int(ceil(Double(count) * 0.95)) - 1],
                "max_ms": sorted.last!, "mean_ms": wall.reduce(0, +) / Double(count),
                "self_cpu_ms_per_call": (cpuMS() - cpu) / Double(count),
                "children_cpu_ms_per_call": (cpuMS(RUSAGE_CHILDREN) - child) / Double(count)])
        }
        if CommandLine.arguments.contains("--spaced") {
            let hid = HIDTemperatureReader()
            bench("HID read at 3-second cadence", count: 20, gap: 3) { hid?.read() }
            print(String(decoding: try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self))
            return
        }
        bench("HID init", count: 10) { HIDTemperatureReader() }
        bench("SMC init", count: 10) { SMCReader() }
        bench("GPU init", count: 10) { GPUPowerReader() }
        let hid = HIDTemperatureReader(), smc = SMCReader(), gpu = GPUPowerReader()
        let raw = hid?.read() ?? []
        let footprints = MemoryStats.appFootprints()
        let snapshot = ProcessSampler.snapshot()
        bench("HID read") { hid?.read() }
        bench("HID read spaced", count: 15, gap: 1) { hid?.read() }
        bench("temperature select and sort") {
            let values = TemperatureSensors.byName(TemperatureSensors.usable(raw))
            return (values, TemperatureSensors.cpuTemperature(from: values))
        }
        bench("SMC fans") { smc?.fans() }
        bench("SMC power") { smc?.systemPower() }
        bench("GPU energy sample") { gpu?.sample() }
        bench("CPU ticks") { CPULoad.sample() }
        bench("system memory") { MemoryStats.read() }
        bench("app footprints") { MemoryStats.appFootprints() }
        bench("footprint ranking") { MemoryStats.ranked(footprints ?? [:]) }
        bench("process snapshot", count: 30) { ProcessSampler.snapshot() }
        let sampler = ProcessSampler()
        if let snapshot {
            _ = sampler.sample(snapshot)
            bench("process aggregation") {
                sampler.sample(ProcessSnapshot(times: snapshot.times, uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds))
            }
        }
        let report: [String: Any] = ["date": ISO8601DateFormatter().string(from: .now),
            "os": ProcessInfo.processInfo.operatingSystemVersionString,
            "cores": ProcessInfo.processInfo.processorCount, "raw_sensor_count": raw.count,
            "display_sensor_count": TemperatureSensors.byName(TemperatureSensors.usable(raw)).count,
            "pids": ProcessSampler.allPids()?.count ?? 0, "snapshot_pids": snapshot?.times.count ?? 0,
            "footprint_groups": footprints?.count ?? 0, "fan_count": smc?.fans()?.count ?? -1,
            "gpu_available": gpu?.sample() != nil, "results": results]
        print(String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self))
    }
}
