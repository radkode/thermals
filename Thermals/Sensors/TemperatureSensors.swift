import Foundation

struct SensorReading: Identifiable, Equatable {
    let id: Int
    let name: String
    let celsius: Double
}

enum TemperatureSensors {
    static let plausibleRange = 1.0...130.0

    /// Real temperatures only: drops implausible values and `tcal` calibration constants.
    static func usable(_ readings: [SensorReading]) -> [SensorReading] {
        readings.filter {
            plausibleRange.contains($0.celsius) && !$0.name.localizedCaseInsensitiveContains("tcal")
        }
    }

    /// Hottest CPU die reading. Prefers `tdie` sensors, falls back to other PMU sensors, never guesses from battery or storage.
    static func cpuTemperature(from readings: [SensorReading]) -> Double? {
        let usable = usable(readings)
        let dies = usable.filter { $0.name.localizedCaseInsensitiveContains("tdie") }
        let pmu = usable.filter { $0.name.hasPrefix("PMU") }
        return (dies.isEmpty ? pmu : dies).map(\.celsius).max()
    }
}

/// Apple Silicon temperature sensors via the private IOKit HID event system, resolved at runtime.
final class HIDTemperatureReader {
    private typealias ClientCreate = @convention(c) (CFAllocator?) -> UnsafeMutableRawPointer?
    private typealias ClientSetMatching = @convention(c) (UnsafeMutableRawPointer, CFDictionary) -> Int32
    private typealias ClientCopyServices = @convention(c) (UnsafeMutableRawPointer) -> UnsafeMutableRawPointer?
    private typealias ServiceCopyProperty = @convention(c) (UnsafeMutableRawPointer, CFString) -> UnsafeMutableRawPointer?
    private typealias ServiceCopyEvent = @convention(c) (UnsafeMutableRawPointer, Int64, Int32, Int64) -> UnsafeMutableRawPointer?
    private typealias EventGetFloatValue = @convention(c) (UnsafeMutableRawPointer, Int32) -> Double

    private static let temperatureEventType: Int64 = 15
    private static let temperatureField = Int32(temperatureEventType << 16)

    private let client: UnsafeMutableRawPointer
    private let copyServices: ClientCopyServices
    private let copyProperty: ServiceCopyProperty
    private let copyEvent: ServiceCopyEvent
    private let getFloatValue: EventGetFloatValue

    init?() {
        guard let iokit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW),
              let create: ClientCreate = Self.symbol(iokit, "IOHIDEventSystemClientCreate"),
              let setMatching: ClientSetMatching = Self.symbol(iokit, "IOHIDEventSystemClientSetMatching"),
              let copyServices: ClientCopyServices = Self.symbol(iokit, "IOHIDEventSystemClientCopyServices"),
              let copyProperty: ServiceCopyProperty = Self.symbol(iokit, "IOHIDServiceClientCopyProperty"),
              let copyEvent: ServiceCopyEvent = Self.symbol(iokit, "IOHIDServiceClientCopyEvent"),
              let getFloatValue: EventGetFloatValue = Self.symbol(iokit, "IOHIDEventGetFloatValue"),
              let client = create(kCFAllocatorDefault)
        else { return nil }

        let matching = ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5] as CFDictionary
        _ = setMatching(client, matching)

        self.client = client
        self.copyServices = copyServices
        self.copyProperty = copyProperty
        self.copyEvent = copyEvent
        self.getFloatValue = getFloatValue
    }

    deinit {
        Unmanaged<AnyObject>.fromOpaque(client).release()
    }

    func read() -> [SensorReading] {
        guard let servicesRef = copyServices(client) else { return [] }
        let services = Unmanaged<CFArray>.fromOpaque(servicesRef).takeRetainedValue()

        var readings: [SensorReading] = []
        for index in 0..<CFArrayGetCount(services) {
            guard let service = CFArrayGetValueAtIndex(services, index).map({ UnsafeMutableRawPointer(mutating: $0) }),
                  let nameRef = copyProperty(service, "Product" as CFString),
                  let name = Unmanaged<AnyObject>.fromOpaque(nameRef).takeRetainedValue() as? String,
                  let event = copyEvent(service, Self.temperatureEventType, 0, 0)
            else { continue }
            let celsius = getFloatValue(event, Self.temperatureField)
            Unmanaged<AnyObject>.fromOpaque(event).release()
            readings.append(SensorReading(id: index, name: name, celsius: celsius))
        }
        return readings
    }

    private static func symbol<T>(_ handle: UnsafeMutableRawPointer, _ name: String) -> T? {
        dlsym(handle, name).map { unsafeBitCast($0, to: T.self) }
    }
}
