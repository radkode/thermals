import Foundation

struct ThermalSession: Codable, Equatable {
    let startedAt: Date
    var lastObservedAt: Date
    var endedAt: Date?
    var interrupted = false
    var hasGaps = false
    var peak: Double?
    var observedSeconds: TimeInterval = 0
    var pressureSeconds: TimeInterval = 0
    var energyWh = 0.0
    var powerSeconds: TimeInterval = 0
    private var previousWatts: Double?
    private var previousPressure = false
    private var hasSample = false

    init(at date: Date) { startedAt = date; lastObservedAt = date }
    var duration: TimeInterval { max(0, (endedAt ?? lastObservedAt).timeIntervalSince(startedAt)) }

    mutating func observe(at date: Date, celsius: Double?, pressure: ProcessInfo.ThermalState, watts: Double?) {
        guard endedAt == nil else { return }
        let elapsed = date.timeIntervalSince(lastObservedAt)
        guard elapsed >= 0 else { hasGaps = true; previousWatts = nil; previousPressure = false; hasSample = false; return }
        let pressured = pressure == .serious || pressure == .critical
        let watts = watts.flatMap { $0.isFinite && $0 > 0 && $0 < 500 ? $0 : nil }
        if hasSample && elapsed <= 30 {
            observedSeconds += elapsed
            if pressured && previousPressure { pressureSeconds += elapsed }
            if let previousWatts, let watts {
                energyWh += (previousWatts + watts) / 2 * elapsed / 3600
                powerSeconds += elapsed
            }
        } else if elapsed > 30 { hasGaps = true }
        if let celsius, celsius.isFinite { peak = max(peak ?? celsius, celsius) }
        lastObservedAt = date
        previousWatts = watts
        previousPressure = pressured
        hasSample = true
    }

    func receipt(unit: TemperatureUnit) -> String {
        let energy = powerSeconds > 0 ? String(format: "%.2f Wh", energyWh) : "unavailable"
        return """
        THERMALS · SESSION RECEIPT
        \(startedAt.formatted(date: .abbreviated, time: .standard))
        Duration: \(Format.duration(duration))
        Observed: \(Format.duration(observedSeconds))
        Peak CPU: \(peak.map { "\(Int(unit.value($0).rounded()))\(unit.title)" } ?? "unavailable")
        Serious/critical pressure: \(Format.duration(pressureSeconds)) observed
        Whole-system energy: \(energy) over \(Format.duration(powerSeconds)) of measured power
        \(interrupted ? "Recording interrupted at the last observation." : "Recording stopped by you.")\(hasGaps ? " Gaps excluded." : "")
        Energy includes all work on this Mac, not just your build or render. Pressure time counts intervals serious/critical at both ends. No process names included.
        """
    }
}

struct ThermalSessions: Codable, Equatable {
    static let storageKey = "thermalSessions"
    private(set) var current: ThermalSession?
    private(set) var last: ThermalSession?

    mutating func start(at date: Date) {
        guard current == nil else { return }
        current = ThermalSession(at: date)
    }

    mutating func observe(at date: Date, celsius: Double?, pressure: ProcessInfo.ThermalState, watts: Double?) {
        current?.observe(at: date, celsius: celsius, pressure: pressure, watts: watts)
    }

    mutating func finish(interrupted: Bool = false) {
        guard var session = current else { return }
        session.endedAt = session.lastObservedAt
        session.interrupted = interrupted
        last = session
        current = nil
    }
}
