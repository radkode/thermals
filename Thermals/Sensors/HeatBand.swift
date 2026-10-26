import Foundation

enum HeatBand: Int, Comparable, CaseIterable {
    case cool, warm, hot, burn

    /// Apple Silicon dies throttle in the high 90s; bands leave headroom before that.
    init(celsius: Double) {
        switch celsius {
        case ..<50: self = .cool
        case ..<75: self = .warm
        case ..<90: self = .hot
        default: self = .burn
        }
    }

    /// Band shown in the menu bar: the reading's band, raised to at least `hot` under serious thermal pressure.
    static func menuBar(celsius: Double?, thermalState: ProcessInfo.ThermalState) -> HeatBand? {
        let reading = celsius.map(HeatBand.init(celsius:))
        let pressure: HeatBand? = switch thermalState {
        case .serious: .hot
        case .critical: .burn
        default: nil
        }
        return [reading, pressure].compactMap { $0 }.max()
    }

    var title: String {
        switch self {
        case .cool: "COOL"
        case .warm: "WARM"
        case .hot: "HOT"
        case .burn: "BURN"
        }
    }

    static func < (lhs: HeatBand, rhs: HeatBand) -> Bool { lhs.rawValue < rhs.rawValue }
}
