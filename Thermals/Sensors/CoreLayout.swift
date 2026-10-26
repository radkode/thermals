import Foundation
import IOKit

enum CoreCluster: String {
    case performance = "P"
    case efficiency = "E"
}

struct CoreInfo: Equatable {
    let logicalID: Int
    let cluster: CoreCluster?
}

struct CoreLoad: Identifiable, Equatable {
    let name: String
    let cluster: CoreCluster?
    let usage: Double
    var id: String { name }
}

enum CoreLayout {
    /// Board names in display order: performance cores P1..., then efficiency E1..., each by logical id; unknown clusters fall back to CPU1....
    static func names(for cores: [CoreInfo]) -> [(logicalID: Int, name: String, cluster: CoreCluster?)] {
        guard cores.allSatisfy({ $0.cluster != nil }) else {
            return cores.sorted { $0.logicalID < $1.logicalID }.enumerated().map { ($1.logicalID, "CPU\($0 + 1)", nil) }
        }
        return [CoreCluster.performance, .efficiency].flatMap { cluster in
            cores.filter { $0.cluster == cluster }
                .sorted { $0.logicalID < $1.logicalID }
                .enumerated()
                .map { ($1.logicalID, "\(cluster.rawValue)\($0 + 1)", cluster) }
        }
    }

    /// Apple Silicon cores from the device tree's `cpus` node; empty when the tree has no cluster data.
    static func read() -> [CoreInfo] {
        let cpus = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/cpus")
        guard cpus != MACH_PORT_NULL else { return [] }
        defer { IOObjectRelease(cpus) }

        var iterator: io_iterator_t = 0
        guard IORegistryEntryGetChildIterator(cpus, kIODeviceTreePlane, &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        var cores: [CoreInfo] = []
        while case let entry = IOIteratorNext(iterator), entry != MACH_PORT_NULL {
            defer { IOObjectRelease(entry) }
            guard let id = integer(property(entry, "logical-cpu-id")) else { continue }
            let clusterName = (property(entry, "cluster-type") as? Data).flatMap { String(data: $0.prefix { $0 != 0 }, encoding: .ascii) }
            cores.append(CoreInfo(logicalID: id, cluster: clusterName.flatMap(CoreCluster.init(rawValue:))))
        }
        return cores
    }

    private static func property(_ entry: io_registry_entry_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }

    /// Device-tree integers arrive as numbers or as little-endian data depending on the node.
    private static func integer(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let data = value as? Data, data.count >= 4 { return data.withUnsafeBytes { Int($0.loadUnaligned(as: UInt32.self)) } }
        return nil
    }
}
