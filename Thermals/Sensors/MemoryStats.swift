import Darwin

/// The kernel's memory pressure level (`kern.memorystatus_vm_pressure_level`), a discrete state like thermal pressure.
enum MemoryPressure: Equatable {
    case normal, warn, critical

    init?(kernelLevel: Int32) {
        switch kernelLevel {
        case 1: self = .normal
        case 2: self = .warn
        case 4: self = .critical
        default: return nil
        }
    }
}

/// Page counts from `HOST_VM_INFO64`, the inputs to the Activity Monitor style breakdown.
struct VMPages: Equatable {
    var anonymous: UInt64
    var purgeable: UInt64
    var external: UInt64
    var wired: UInt64
    var compressed: UInt64
    /// Free minus speculative, as `vm_stat` reports it.
    var free: UInt64
}

/// Physical memory split the way Activity Monitor splits it, plus the pages nothing holds. Bytes throughout.
struct MemoryReading: Equatable {
    let total: UInt64
    let app: UInt64
    let wired: UInt64
    let compressed: UInt64
    let cached: UInt64
    let free: UInt64
    let swapUsed: UInt64?
    let pressure: MemoryPressure?

    /// What can't be reclaimed without paging: app, wired and compressed.
    var used: UInt64 { app + wired + compressed }
    var usedPercent: Double { total > 0 ? Double(used) / Double(total) * 100 : 0 }

    init(total: UInt64, app: UInt64, wired: UInt64, compressed: UInt64, cached: UInt64, free: UInt64, swapUsed: UInt64?, pressure: MemoryPressure?) {
        self.total = total
        self.app = app
        self.wired = wired
        self.compressed = compressed
        self.cached = cached
        self.free = free
        self.swapUsed = swapUsed
        self.pressure = pressure
    }

    /// Purgeable pages count as cache, not app memory, since the system can drop them at will.
    init(pages: VMPages, pageSize: UInt64, total: UInt64, swapUsed: UInt64?, pressure: MemoryPressure?) {
        let anonymous = pages.anonymous > pages.purgeable ? pages.anonymous - pages.purgeable : 0
        self.init(
            total: total,
            app: anonymous * pageSize,
            wired: pages.wired * pageSize,
            compressed: pages.compressed * pageSize,
            cached: (pages.external + pages.purgeable) * pageSize,
            free: pages.free * pageSize,
            swapUsed: swapUsed,
            pressure: pressure
        )
    }
}

struct AppMemory: Identifiable, Equatable {
    let name: String
    let bytes: UInt64
    var id: String { name }
}

enum MemoryStats {
    /// Each `mach_host_self()` call adds a send-right reference, so it is taken once.
    private static let host = mach_host_self()

    static func read() -> MemoryReading? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(host, HOST_VM_INFO64, $0, &count) }
        }
        var pageSize: vm_size_t = 0
        guard result == KERN_SUCCESS, host_page_size(host, &pageSize) == KERN_SUCCESS,
              let total: UInt64 = sysctl("hw.memsize")
        else { return nil }
        let pages = VMPages(
            anonymous: UInt64(stats.internal_page_count),
            purgeable: UInt64(stats.purgeable_count),
            external: UInt64(stats.external_page_count),
            wired: UInt64(stats.wire_count),
            compressed: UInt64(stats.compressor_page_count),
            free: UInt64(stats.free_count > stats.speculative_count ? stats.free_count - stats.speculative_count : 0)
        )
        let swap: xsw_usage? = sysctl("vm.swapusage")
        let level: Int32? = sysctl("kern.memorystatus_vm_pressure_level")
        return MemoryReading(
            pages: pages,
            pageSize: UInt64(pageSize),
            total: total,
            swapUsed: swap?.xsu_used,
            pressure: level.flatMap(MemoryPressure.init(kernelLevel:))
        )
    }

    /// Physical footprint per app (helpers grouped under their app), as Activity Monitor's Memory column. Only this user's processes are visible.
    static func appFootprints() -> [String: UInt64] {
        var result: [String: UInt64] = [:]
        for pid in ProcessSampler.allPids() {
            var info = rusage_info_v4()
            let status = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V4, $0) }
            }
            guard status == 0, let name = ProcessSampler.groupName(pid: pid) else { continue }
            result[name, default: 0] += info.ri_phys_footprint
        }
        return result
    }

    static func ranked(_ footprints: [String: UInt64]) -> [AppMemory] {
        footprints.map { AppMemory(name: $0.key, bytes: $0.value) }
            .sorted { ($0.bytes, $1.name) > ($1.bytes, $0.name) }
    }

    private static func sysctl<T>(_ name: String) -> T? {
        var value = [UInt8](repeating: 0, count: MemoryLayout<T>.size)
        var size = value.count
        guard sysctlbyname(name, &value, &size, nil, 0) == 0, size == MemoryLayout<T>.size else { return nil }
        return value.withUnsafeBytes { $0.loadUnaligned(as: T.self) }
    }
}
