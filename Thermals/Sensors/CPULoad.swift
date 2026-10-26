import Darwin

struct CPUTicks: Equatable {
    var user: UInt64
    var system: UInt64
    var idle: UInt64
    var nice: UInt64

    var busy: UInt64 { user + system + nice }
    var total: UInt64 { busy + idle }
}

enum CPULoad {
    /// Fraction of time (0...1) spent busy between two samples, or nil when no ticks elapsed.
    static func usage(from previous: CPUTicks, to current: CPUTicks) -> Double? {
        guard current.total > previous.total, current.busy >= previous.busy else { return nil }
        return Double(current.busy - previous.busy) / Double(current.total - previous.total)
    }

    /// Cumulative ticks summed across all cores.
    static func sample() -> CPUTicks? {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount)
        guard result == KERN_SUCCESS, let info else { return nil }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))
        }

        var ticks = CPUTicks(user: 0, system: 0, idle: 0, nice: 0)
        for cpu in 0..<Int(cpuCount) {
            let base = cpu * Int(CPU_STATE_MAX)
            ticks.user += UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]))
            ticks.system += UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]))
            ticks.idle += UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]))
            ticks.nice += UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)]))
        }
        return ticks
    }
}
