import Foundation

struct HeatEpisode: Codable, Equatable, Identifiable {
    var id: Date { startedAt }
    let startedAt: Date
    var lastObservedAt: Date
    var endedAt: Date?
    var interrupted = false
    var peak: Double?
    var pressureSeconds: TimeInterval = 0
    var systemWatts: Double?
    var gpuWatts: Double?
    var topCPU: String?
    var duration: TimeInterval { max(0, lastObservedAt.timeIntervalSince(startedAt)) }
}

struct HeatEpisodeRecorder: Codable, Equatable {
    static let storageKey = "heatEpisodes"
    static let maximumGap: TimeInterval = 30
    private(set) var current: HeatEpisode?
    private(set) var recent: [HeatEpisode] = []
    private var previousPressure = false
    private var recoveredAt: Date?

    mutating func observe(at date: Date, celsius: Double?, pressure: ProcessInfo.ThermalState,
                          systemWatts: Double?, gpuWatts: Double?, activity: HeatActivity?) {
        let pressured = pressure == .serious || pressure == .critical
        if let current {
            let gap = date.timeIntervalSince(current.lastObservedAt)
            if gap < 0 || gap > Self.maximumGap || (celsius == nil && !pressured) { finish(interrupted: true) }
        }
        if current == nil {
            guard (celsius ?? 0) >= 85 || pressured else { return }
            current = HeatEpisode(startedAt: date, lastObservedAt: date)
        }
        guard var episode = current else { return }
        if pressured && previousPressure { episode.pressureSeconds += max(0, date.timeIntervalSince(episode.lastObservedAt)) }
        episode.lastObservedAt = date
        if let celsius, episode.peak.map({ celsius > $0 }) ?? true {
            episode.peak = celsius
            episode.topCPU = activity.flatMap { $0.isFresh(at: date) ? $0.process?.name : nil }
        } else if episode.topCPU == nil, let activity, activity.isFresh(at: date) {
            episode.topCPU = activity.process?.name
        }
        if let systemWatts { episode.systemWatts = max(episode.systemWatts ?? 0, systemWatts) }
        if let gpuWatts { episode.gpuWatts = max(episode.gpuWatts ?? 0, gpuWatts) }
        current = episode
        previousPressure = pressured
        if let celsius, celsius < 75, !pressured {
            recoveredAt = recoveredAt ?? date
            if date.timeIntervalSince(recoveredAt!) >= 30 { finish(interrupted: false) }
        } else { recoveredAt = nil }
    }

    mutating func finish(interrupted: Bool) {
        guard var episode = current else { return }
        episode.endedAt = episode.lastObservedAt
        episode.interrupted = interrupted
        recent.insert(episode, at: 0)
        recent = Array(recent.prefix(8))
        current = nil
        previousPressure = false
        recoveredAt = nil
    }
}
