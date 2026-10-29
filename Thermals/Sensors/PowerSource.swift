import Foundation
import IOKit.ps

struct PowerSourceReading: Equatable {
    enum State: String {
        case battery = "ON BATTERY", charging = "CHARGING", pluggedIn = "PLUGGED IN"
        case external = "ON AC POWER", unavailable = "POWER UNKNOWN"
    }
    let state: State
    let adapterWatts: Double?

    static func interpret(sources: [[String: Any]], providing: String?, adapterWatts: Double?) -> Self {
        let battery = sources.first { $0[kIOPSTypeKey] as? String == kIOPSInternalBatteryType && $0[kIOPSIsPresentKey] as? Bool != false }
        let supply = battery?[kIOPSPowerSourceStateKey] as? String ?? providing
        let state: State
        if supply == kIOPSBatteryPowerValue { state = .battery }
        else if supply == kIOPSACPowerValue {
            if let charging = battery?[kIOPSIsChargingKey] as? Bool { state = charging ? .charging : .pluggedIn }
            else { state = .external }
        } else { state = .unavailable }
        let watts = adapterWatts.flatMap { $0.isFinite && $0 > 0 && $0 < 1000 && supply == kIOPSACPowerValue ? $0 : nil }
        return Self(state: state, adapterWatts: watts)
    }

    static func read() -> Self {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return Self(state: .unavailable, adapterWatts: nil) }
        let sources = list.compactMap { IOPSGetPowerSourceDescription(info, $0)?.takeUnretainedValue() as? [String: Any] }
        let providing = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
        let adapter = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any]
        return interpret(sources: sources, providing: providing, adapterWatts: adapter?[kIOPSPowerAdapterWattsKey] as? Double)
    }
}
