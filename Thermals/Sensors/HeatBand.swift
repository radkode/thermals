import Foundation

/// A reading's place on one continuous heat scale (0...1), shared by every color in the app and the menu bar.
/// Band edges sit at fixed positions, so a temperature and a load in the same band land in the same stretch of the gradient.
struct HeatLevel: Comparable {
    let position: Double

    /// Positions where WARM, HOT and BURN begin.
    static let warmStart = 1.0 / 3
    static let hotStart = 2.0 / 3
    static let burnStart = 0.85

    init(position: Double) {
        self.position = min(1, max(0, position))
    }

    /// Apple Silicon dies throttle in the high 90s; bands leave headroom before that.
    init(celsius: Double) {
        self.init(position: Self.interpolate(celsius, anchors: [(30, 0), (50, Self.warmStart), (75, Self.hotStart), (90, Self.burnStart), (105, 1)]))
    }

    /// Load as heat: `percent` is of one core for a single core or process, or of the whole CPU for the total.
    init(loadPercent percent: Double) {
        self.init(position: Self.interpolate(percent, anchors: [(0, 0), (25, Self.warmStart), (60, Self.hotStart), (85, Self.burnStart), (100, 1)]))
    }

    /// Menu bar temperature: the reading's level, raised to at least HOT under serious and BURN under critical thermal pressure.
    static func menuBar(celsius: Double?, thermalState: ProcessInfo.ThermalState) -> HeatLevel? {
        let reading = celsius.map(HeatLevel.init(celsius:))
        let pressure: HeatLevel? = switch thermalState {
        case .serious: HeatLevel(position: hotStart)
        case .critical: HeatLevel(position: burnStart)
        default: nil
        }
        return [reading, pressure].compactMap { $0 }.max()
    }

    var band: HeatBand {
        switch position {
        case ..<Self.warmStart: .cool
        case ..<Self.hotStart: .warm
        case ..<Self.burnStart: .hot
        default: .burn
        }
    }

    static func < (lhs: HeatLevel, rhs: HeatLevel) -> Bool { lhs.position < rhs.position }

    private static func interpolate(_ value: Double, anchors: [(value: Double, position: Double)]) -> Double {
        guard let first = anchors.first, let last = anchors.last else { return 0 }
        if value <= first.value { return first.position }
        if value >= last.value { return last.position }
        for (low, high) in zip(anchors, anchors.dropFirst()) where value < high.value {
            return low.position + (value - low.value) / (high.value - low.value) * (high.position - low.position)
        }
        return last.position
    }
}

enum HeatBand: Int, Comparable, CaseIterable {
    case cool, warm, hot, burn

    init(celsius: Double) { self = HeatLevel(celsius: celsius).band }
    init(loadPercent percent: Double) { self = HeatLevel(loadPercent: percent).band }

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
