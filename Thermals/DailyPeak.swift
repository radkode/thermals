import Foundation

/// The hottest CPU die reading since local midnight, with the busiest process sampled near that moment.
struct DailyPeak: Codable, Equatable {
    let celsius: Double
    let date: Date
    var culprit: String?
    /// The peak `date` the culprit was sampled for; behind `date` once the peak has risen since.
    var attributedDate: Date?

    /// Below WARM the busiest process says nothing about heat.
    static let attributionFloor = 50.0
    static let attributionInterval: TimeInterval = 30
    /// How far from a peak a process sample still describes it; older peaks stay unattributed rather than name a later workload.
    static let attributionWindow: TimeInterval = 60
    static let storageKey = "dailyPeak"

    /// A new day starts a new peak. Within a day the peak moves only when the displayed whole degree rises, keeping the time it
    /// first reached that degree. A culprit sampled within `attributionWindow` carries over until a fresh sample, since a
    /// climbing peak is usually one workload; an older one is dropped.
    static func updated(_ peak: DailyPeak?, celsius: Double, at now: Date, calendar: Calendar = .current) -> DailyPeak {
        guard let peak, calendar.isDate(peak.date, inSameDayAs: now) else { return DailyPeak(celsius: celsius, date: now) }
        guard celsius.rounded() > peak.celsius.rounded() else { return peak }
        guard let sampled = peak.attributedDate, now.timeIntervalSince(sampled) <= attributionWindow else {
            return DailyPeak(celsius: celsius, date: now)
        }
        return DailyPeak(celsius: celsius, date: now, culprit: peak.culprit, attributedDate: sampled)
    }

    /// Sample processes when the peak is warm, its culprit predates it, and the last sample is at least `attributionInterval` old.
    func needsAttribution(at now: Date, lastSampled: Date?) -> Bool {
        celsius.rounded() >= Self.attributionFloor
            && attributedDate != date
            && now.timeIntervalSince(date) <= Self.attributionWindow
            && (lastSampled.map { now.timeIntervalSince($0) >= Self.attributionInterval } ?? true)
    }

    /// The culprit sampled for the peak at `date`, kept only while the peak is still from that day. A failed sample changes
    /// nothing, so it is retried within the window.
    func attributed(_ culprit: String?, for date: Date, calendar: Calendar = .current) -> DailyPeak {
        guard let culprit, calendar.isDate(self.date, inSameDayAs: date) else { return self }
        var peak = self
        peak.culprit = culprit
        peak.attributedDate = date
        return peak
    }
}
