import Foundation
import Darwin

@main struct ProcessBench {
    static func main() throws {
        let pid = pid_t(CommandLine.arguments[1])!
        let seconds = Int(CommandLine.arguments[2])!
        var rows: [[String: Any]] = []
        for i in 0...seconds {
            var info = rusage_info_v4()
            let status = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V4, $0) }
            }
            guard status == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
            rows.append(["elapsed": i, "uptime_ns": DispatchTime.now().uptimeNanoseconds,
                "cpu_ns": info.ri_user_time + info.ri_system_time,
                "child_cpu_ns": info.ri_child_user_time + info.ri_child_system_time,
                "footprint": info.ri_phys_footprint, "resident": info.ri_resident_size,
                "idle_wakeups": info.ri_pkg_idle_wkups, "interrupt_wakeups": info.ri_interrupt_wkups,
                "disk_read": info.ri_diskio_bytesread, "disk_write": info.ri_diskio_byteswritten])
            if i < seconds { Thread.sleep(forTimeInterval: 1) }
        }
        print(String(decoding: try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self))
    }
}
