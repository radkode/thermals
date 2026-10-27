import Darwin

struct CPUTicks: Equatable {
    var user: UInt64
    var system: UInt64
    var idle: UInt64
    var nice: UInt64

    var busy: UInt64 { user + system + nice }
    var total: UInt64 { busy + idle }

    static let zero = CPUTicks(user: 0, system: 0, idle: 0, nice: 0)

    static func + (lhs: CPUTicks, rhs: CPUTicks) -> CPUTicks {
        CPUTicks(user: lhs.user + rhs.user, system: lhs.system + rhs.system, idle: lhs.idle + rhs.idle, nice: lhs.nice + rhs.nice)
    }
}

enum CPULoad {
    /// Each `mach_host_self()` call adds a send-right reference, so it is taken once.
    private static let host = mach_host_self()

    /// Fraction of time (0...1) spent busy between two samples, or nil when no ticks elapsed.
    static func usage(from previous: CPUTicks, to current: CPUTicks) -> Double? {
        guard current.total > previous.total, current.busy >= previous.busy else { return nil }
        return Double(current.busy - previous.busy) / Double(current.total - previous.total)
    }

    /// Cumulative ticks per logical CPU, indexed by logical CPU id.
    static func sample() -> [CPUTicks]? {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let result = host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount)
        guard result == KERN_SUCCESS, let info else { return nil }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))
        }

        return (0..<Int(cpuCount)).map { cpu in
            let base = cpu * Int(CPU_STATE_MAX)
            return CPUTicks(
                user: UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_USER)])),
                system: UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)])),
                idle: UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)])),
                nice: UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)]))
            )
        }
    }
}
