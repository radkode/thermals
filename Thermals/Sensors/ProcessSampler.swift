import Darwin
import Foundation

struct ProcessLoad: Identifiable, Equatable {
    let name: String
    /// Percent of one core, so a busy multithreaded app can exceed 100.
    let percent: Double
    var id: String { name }
}

struct ProcessTimes: Equatable {
    let name: String
    let cpuNanoseconds: UInt64
}

/// CPU use per process name from `proc_pidinfo` deltas. Only processes this user may inspect are visible; root and system processes are not.
final class ProcessSampler {
    private var previous: [pid_t: ProcessTimes] = [:]
    private var previousTime: UInt64 = 0
    private var smoothed: [String: Double] = [:]
    private let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    func sample() -> [ProcessLoad] {
        let now = DispatchTime.now().uptimeNanoseconds
        let current = Self.readAll(timebase: timebase)
        defer {
            previous = current
            previousTime = now
        }
        guard previousTime > 0 else { return [] }
        let percents = Self.percents(previous: previous, current: current, elapsedNanoseconds: now - previousTime)
        smoothed = Self.smooth(previous: smoothed, current: percents)
        return Self.ranked(smoothed)
    }

    func reset() {
        previous = [:]
        previousTime = 0
        smoothed = [:]
    }

    /// Percent of one core per process name between two readings; processes absent from `previous` have no baseline and are skipped.
    static func percents(previous: [pid_t: ProcessTimes], current: [pid_t: ProcessTimes], elapsedNanoseconds: UInt64) -> [String: Double] {
        guard elapsedNanoseconds > 0 else { return [:] }
        var byName: [String: Double] = [:]
        for (pid, times) in current {
            guard let before = previous[pid], before.name == times.name, times.cpuNanoseconds >= before.cpuNanoseconds else { continue }
            byName[times.name, default: 0] += Double(times.cpuNanoseconds - before.cpuNanoseconds) / Double(elapsedNanoseconds) * 100
        }
        return byName
    }

    /// Exponential smoothing so ranks settle instead of flickering; names that go quiet decay out.
    static func smooth(previous: [String: Double], current: [String: Double], weight: Double = 0.5) -> [String: Double] {
        var result: [String: Double] = [:]
        for name in Set(previous.keys).union(current.keys) {
            let value = weight * (current[name] ?? 0) + (1 - weight) * (previous[name] ?? current[name] ?? 0)
            if value >= 0.05 { result[name] = value }
        }
        return result
    }

    static func ranked(_ percents: [String: Double]) -> [ProcessLoad] {
        percents.map { ProcessLoad(name: $0.key, percent: $0.value) }
            .sorted { ($0.percent, $1.name) > ($1.percent, $0.name) }
    }

    private static func readAll(timebase: mach_timebase_info_data_t) -> [pid_t: ProcessTimes] {
        let capacity = proc_listallpids(nil, 0) + 64
        guard capacity > 64 else { return [:] }
        var pids = [pid_t](repeating: 0, count: Int(capacity))
        let count = proc_listallpids(&pids, capacity * Int32(MemoryLayout<pid_t>.size))
        var result: [pid_t: ProcessTimes] = [:]
        for pid in pids.prefix(Int(max(count, 0))) where pid > 0 {
            var info = proc_taskinfo()
            let size = Int32(MemoryLayout<proc_taskinfo>.size)
            guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size) == size else { continue }
            var name = [CChar](repeating: 0, count: 64)
            guard proc_name(pid, &name, UInt32(name.count)) > 0 else { continue }
            let ticks = info.pti_total_user + info.pti_total_system
            let nanoseconds = ticks * UInt64(timebase.numer) / UInt64(max(timebase.denom, 1))
            result[pid] = ProcessTimes(name: String(decoding: name.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self), cpuNanoseconds: nanoseconds)
        }
        return result
    }
}
