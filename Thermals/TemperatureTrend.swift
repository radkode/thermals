import Foundation

/// Which way the CPU temperature is heading: the least-squares slope of the last `window` of readings, with a dead zone so
/// sensor jitter reads as steady.
enum TemperatureTrend: Equatable {
    case rising, steady, falling

    static let window: TimeInterval = 60
    /// Readings must span at least this much of the window before a direction is claimed.
    static let minimumSpan: TimeInterval = 30
    /// Degrees Celsius per minute: idle jitter on an M3 Pro reached 3.5, while loaded climbs ran 6 to 10.
    static let deadZone = 5.0

    /// Nil until there are enough recent readings to judge.
    init?(_ readings: [TimedValue], now: Date) {
        let recent = readings.filter { (0...Self.window).contains(now.timeIntervalSince($0.date)) }
        guard recent.count >= 3, let first = recent.map(\.date).min(), let last = recent.map(\.date).max(),
              last.timeIntervalSince(first) >= Self.minimumSpan
        else { return nil }
        let times = recent.map { $0.date.timeIntervalSince(first) / 60 }
        let values = recent.map(\.value)
        let meanTime = times.reduce(0, +) / Double(times.count)
        let meanValue = values.reduce(0, +) / Double(values.count)
        let covariance = zip(times, values).reduce(0) { $0 + ($1.0 - meanTime) * ($1.1 - meanValue) }
        let variance = times.reduce(0) { $0 + ($1 - meanTime) * ($1 - meanTime) }
        let slope = covariance / variance
        guard variance > 0, slope.isFinite else { return nil }
        self = slope >= Self.deadZone ? .rising : slope <= -Self.deadZone ? .falling : .steady
    }

    /// Shown after the temperature; steady shows nothing, so the menu bar only changes when there is a direction to report.
    var glyph: String? {
        switch self {
        case .rising: "↑"
        case .falling: "↓"
        case .steady: nil
        }
    }

    var spoken: String {
        switch self {
        case .rising: "rising"
        case .falling: "falling"
        case .steady: "steady"
        }
    }
}
