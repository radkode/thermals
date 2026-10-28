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
    /// What the board groups by: the outermost app bundle for helpers, else the process name.
    var group: String? = nil
}

struct ProcessSample: Equatable {
    /// Smoothed, ranked by CPU.
    let ranked: [ProcessLoad]
    /// Unsmoothed total of every visible process this interval, in percent of one core.
    let visibleTotal: Double
}

/// Every process's cumulative CPU time at one moment.
struct ProcessSnapshot {
    let times: [pid_t: ProcessTimes]
    let uptimeNanoseconds: UInt64
}

/// CPU use per app from deltas of cumulative CPU time. The times come from the setuid `/bin/ps`, so root and system
/// processes such as `WindowServer` count too; `kernel_task` (pid 0) is the one process `ps` can't report.
final class ProcessSampler {
    private var previous: ProcessSnapshot?
    private var smoothed: [String: Double] = [:]

    /// Nil until there is a baseline to measure against.
    func sample(_ current: ProcessSnapshot) -> ProcessSample? {
        defer { previous = current }
        guard let previous, current.uptimeNanoseconds > previous.uptimeNanoseconds else { return nil }
        let percents = Self.percents(previous: previous.times, current: current.times, elapsedNanoseconds: current.uptimeNanoseconds - previous.uptimeNanoseconds)
        smoothed = Self.smooth(previous: smoothed, current: percents)
        return ProcessSample(ranked: Self.ranked(smoothed), visibleTotal: percents.values.reduce(0, +))
    }

    func reset() {
        previous = nil
        smoothed = [:]
    }

    /// Runs `ps`, which takes around a tenth of a second, so call it off the main actor.
    nonisolated static func snapshot() -> ProcessSnapshot? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,time=,comm="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return ProcessSnapshot(times: parse(String(decoding: output, as: UTF8.self)), uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds)
    }

    /// `ps -axo pid=,time=,comm=` lines: pid, cumulative CPU time, then the executable path, which may contain spaces.
    static func parse(_ output: String) -> [pid_t: ProcessTimes] {
        var result: [pid_t: ProcessTimes] = [:]
        for line in output.split(separator: "\n") {
            let fields = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard fields.count == 3, let pid = pid_t(fields[0]), let seconds = cpuSeconds(String(fields[1])), seconds < 1e9 else { continue }
            let command = String(fields[2])
            let name = command.split(separator: "/").last.map(String.init) ?? command
            result[pid] = ProcessTimes(
                name: name,
                cpuNanoseconds: UInt64(seconds * 1_000_000_000),
                group: groupName(path: command.hasPrefix("/") ? command : nil, processName: name)
            )
        }
        return result
    }

    /// `ps` TIME: `[days-][hours:]minutes:seconds.centiseconds`.
    static func cpuSeconds(_ time: String) -> Double? {
        let dayParts = time.split(separator: "-", omittingEmptySubsequences: false)
        guard (1...2).contains(dayParts.count), let clock = dayParts.last else { return nil }
        let days = dayParts.count == 2 ? Double(dayParts[0]) : 0
        let parts = clock.split(separator: ":", omittingEmptySubsequences: false).map { Double($0) }
        guard let days, (2...3).contains(parts.count), !parts.contains(nil) else { return nil }
        let seconds = parts.compactMap { $0 }.reduce(0) { $0 * 60 + $1 } + days * 86_400
        return seconds.isFinite && seconds >= 0 ? seconds : nil
    }

    /// Helpers group under the outermost `.app` in their path, so Chrome's renderers count as Google Chrome. Other processes are
    /// named from their path, since `proc_name` truncates at 32 characters: version-named binaries take the tool's folder name
    /// (`claude/versions/2.1.310` is claude) and reverse-DNS names keep their last part.
    static func groupName(path: String?, processName: String) -> String {
        guard let path else { return processName }
        let components = path.split(separator: "/").map(String.init)
        if let app = components.first(where: { $0.hasSuffix(".app") }) { return String(app.dropLast(4)) }
        let name = components.suffix(3).reversed().first { !isVersion($0) && !genericFolders.contains($0.lowercased()) } ?? processName
        return shortened(name)
    }

    private static let genericFolders: Set<String> = ["bin", "sbin", "libexec", "versions", "current", "macos", "contents"]

    private static func isVersion(_ name: String) -> Bool {
        name.wholeMatch(of: /[vV]?\d+(\.\d+)+([-+][0-9A-Za-z.-]+)?/) != nil
    }

    private static func shortened(_ name: String) -> String {
        let parts = name.split(separator: ".")
        guard parts.count >= 3, ["com", "org", "io", "net"].contains(parts[0].lowercased()) else { return name }
        return String(parts[parts.count - 1])
    }

    /// Percent of one core per process name between two readings; processes absent from `previous` have no baseline and are skipped.
    static func percents(previous: [pid_t: ProcessTimes], current: [pid_t: ProcessTimes], elapsedNanoseconds: UInt64) -> [String: Double] {
        guard elapsedNanoseconds > 0 else { return [:] }
        var byName: [String: Double] = [:]
        for (pid, times) in current {
            guard let before = previous[pid], before.name == times.name, times.cpuNanoseconds >= before.cpuNanoseconds else { continue }
            byName[times.group ?? times.name, default: 0] += Double(times.cpuNanoseconds - before.cpuNanoseconds) / Double(elapsedNanoseconds) * 100
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

    static func allPids() -> [pid_t]? {
        let capacity = proc_listallpids(nil, 0) + 64
        guard capacity > 64 else { return nil }
        var pids = [pid_t](repeating: 0, count: Int(capacity))
        let count = proc_listallpids(&pids, capacity * Int32(MemoryLayout<pid_t>.size))
        guard count > 0 else { return nil }
        return pids.prefix(Int(count)).filter { $0 > 0 }
    }

    /// The board name for a running pid: its outermost app, else its process name; nil once the process is gone.
    static func groupName(pid: pid_t, processName: String? = nil) -> String? {
        guard let name = processName ?? Self.processName(pid: pid) else { return nil }
        var path = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let pathLength = proc_pidpath(pid, &path, UInt32(path.count))
        return groupName(path: pathLength > 0 ? string(path) : nil, processName: name)
    }

    private static func processName(pid: pid_t) -> String? {
        var name = [CChar](repeating: 0, count: 64)
        guard proc_name(pid, &name, UInt32(name.count)) > 0 else { return nil }
        return string(name)
    }

    private static func string(_ buffer: [CChar]) -> String {
        String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
