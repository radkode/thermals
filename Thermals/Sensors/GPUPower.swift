import Foundation

/// A cumulative energy counter at one moment, in the counter's own unit.
struct EnergySample: Equatable {
    let energy: Int64
    let unit: String
    let uptimeNanoseconds: UInt64
}

enum GPUPower {
    /// Joules per counter unit for the labels IOReport uses; anything else is nil rather than a guess.
    static func joules(perUnit label: String) -> Double? {
        switch label.trimmingCharacters(in: .whitespaces) {
        case "mJ": 1e-3
        case "uJ", "µJ": 1e-6
        case "nJ": 1e-9
        default: nil
        }
    }

    /// Average watts between two samples; nil when time didn't advance, the counter went backwards, or the result is implausible.
    static func watts(from previous: EnergySample, to current: EnergySample) -> Double? {
        guard current.unit == previous.unit,
              current.uptimeNanoseconds > previous.uptimeNanoseconds,
              case let (delta, overflow) = current.energy.subtractingReportingOverflow(previous.energy),
              !overflow, delta >= 0,
              let scale = joules(perUnit: current.unit)
        else { return nil }
        let seconds = Double(current.uptimeNanoseconds - previous.uptimeNanoseconds) / 1e9
        let watts = Double(delta) * scale / seconds
        return watts.isFinite && watts < 500 ? watts : nil
    }
}

/// Watts from successive GPU energy samples. Stays unavailable until the counter has moved once, so a counter macOS
/// freezes for unprivileged processes (as it does the CPU ones on macOS 27) never reads as an idle 0 W.
struct GPUPowerMeter {
    private var previous: EnergySample?
    private var advanced = false

    mutating func watts(_ sample: EnergySample) -> Double? {
        defer { previous = sample }
        guard let previous, previous.unit == sample.unit else { return nil }
        if sample.energy > previous.energy { advanced = true }
        return advanced ? GPUPower.watts(from: previous, to: sample) : nil
    }
}

/// GPU energy from IOReport's private `Energy Model` group, resolved at runtime.
final class GPUPowerReader {
    private typealias CopyChannelsInGroup = @convention(c) (CFString, CFString?, UInt64, UInt64, UInt64) -> Unmanaged<CFDictionary>?
    private typealias CreateSubscription = @convention(c) (UnsafeMutableRawPointer?, CFMutableDictionary, UnsafeMutablePointer<Unmanaged<CFMutableDictionary>?>, UInt64, CFTypeRef?) -> UnsafeMutableRawPointer?
    private typealias CreateSamples = @convention(c) (UnsafeMutableRawPointer, CFMutableDictionary, CFTypeRef?) -> Unmanaged<CFDictionary>?
    private typealias ChannelString = @convention(c) (CFDictionary) -> Unmanaged<CFString>?
    private typealias IntegerValue = @convention(c) (CFDictionary, Int32) -> Int64

    private static let channelName = "GPU Energy"

    private let subscription: UnsafeMutableRawPointer
    private let channels: CFMutableDictionary
    private let createSamples: CreateSamples
    private let channelNameOf: ChannelString
    private let unitOf: ChannelString
    private let integerValue: IntegerValue

    init?() {
        guard let library = dlopen("/usr/lib/libIOReport.dylib", RTLD_NOW),
              let copyChannels: CopyChannelsInGroup = Self.symbol(library, "IOReportCopyChannelsInGroup"),
              let createSubscription: CreateSubscription = Self.symbol(library, "IOReportCreateSubscription"),
              let createSamples: CreateSamples = Self.symbol(library, "IOReportCreateSamples"),
              let channelNameOf: ChannelString = Self.symbol(library, "IOReportChannelGetChannelName"),
              let unitOf: ChannelString = Self.symbol(library, "IOReportChannelGetUnitLabel"),
              let integerValue: IntegerValue = Self.symbol(library, "IOReportSimpleGetIntegerValue"),
              let group = copyChannels("Energy Model" as CFString, nil, 0, 0, 0)?.takeRetainedValue(),
              let requested = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, group)
        else { return nil }
        var subscribed: Unmanaged<CFMutableDictionary>?
        guard let subscription = createSubscription(nil, requested, &subscribed, 0, nil),
              let channels = subscribed?.takeRetainedValue()
        else { return nil }
        self.subscription = subscription
        self.channels = channels
        self.createSamples = createSamples
        self.channelNameOf = channelNameOf
        self.unitOf = unitOf
        self.integerValue = integerValue
    }

    deinit {
        Unmanaged<AnyObject>.fromOpaque(subscription).release()
    }

    func sample() -> EnergySample? {
        guard let samples = createSamples(subscription, channels, nil)?.takeRetainedValue() as NSDictionary?,
              let list = samples["IOReportChannels"] as? [NSDictionary]
        else { return nil }
        for channel in list where channelNameOf(channel)?.takeUnretainedValue() as String? == Self.channelName {
            guard let unit = unitOf(channel)?.takeUnretainedValue() as String? else { return nil }
            return EnergySample(energy: integerValue(channel, 0), unit: unit, uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds)
        }
        return nil
    }

    private static func symbol<T>(_ handle: UnsafeMutableRawPointer, _ name: String) -> T? {
        dlsym(handle, name).map { unsafeBitCast($0, to: T.self) }
    }
}
