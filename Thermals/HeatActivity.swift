import Foundation

struct HeatActivity: Equatable {
    let process: ProcessLoad?
    let date: Date

    func isFresh(at now: Date) -> Bool { (0...45).contains(now.timeIntervalSince(date)) }

    static func shouldSample(celsius: Double?, pressure: ProcessInfo.ThermalState, trend: TemperatureTrend?, visible: Bool) -> Bool {
        visible || (celsius ?? 0) >= 75 || pressure == .serious || pressure == .critical || trend == .rising
    }
}

@MainActor
final class ActivitySampler {
    private var pending: Task<HeatActivity, Never>?
    private var latest: HeatActivity?
    private let read: @Sendable () async -> ProcessLoad?

    init(read: @escaping @Sendable () async -> ProcessLoad? = { await ProcessSampler.busiest() }) { self.read = read }

    func sample() async -> HeatActivity {
        if let latest, (0...5).contains(Date.now.timeIntervalSince(latest.date)) { return latest }
        if let pending { return await pending.value }
        let read = read
        let task = Task { HeatActivity(process: await read(), date: .now) }
        pending = task
        let result = await task.value
        latest = result
        pending = nil
        return result
    }

    func record(_ process: ProcessLoad?, at date: Date) { latest = HeatActivity(process: process, date: date) }
}
