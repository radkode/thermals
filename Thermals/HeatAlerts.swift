import Foundation
import UserNotifications

enum HeatAlertsSetting: String, FlapTabOption {
    case on, off

    var title: String {
        switch self {
        case .on: "ON"
        case .off: "OFF"
        }
    }
}

/// Decides when heat is worth a notification: BURN or serious thermal pressure held for `sustain`, once per episode.
/// An episode ends only when the Mac cools below HOT, and alerts stay at least `cooldown` apart.
struct HeatAlertTrigger {
    static let sustain: TimeInterval = 30
    static let cooldown: TimeInterval = 600

    private var hotSince: Date?
    private var lastObserved: Date?
    private var lastAlert: Date?
    private var armed = true

    /// True when this reading should raise an alert.
    mutating func observe(celsius: Double?, thermalState: ProcessInfo.ThermalState, at now: Date) -> Bool {
        defer { lastObserved = now }
        let burning = celsius.map { HeatBand(celsius: $0.rounded()) == .burn } ?? false
        let throttled = thermalState == .serious || thermalState == .critical
        guard burning || throttled else {
            hotSince = nil
            if (HeatLevel.menuBar(celsius: celsius?.rounded(), thermalState: thermalState)?.band ?? .cool) < .hot { armed = true }
            return false
        }
        // A gap longer than the sustain window (the Mac slept) restarts the count rather than counting the gap as heat.
        if let lastObserved, now.timeIntervalSince(lastObserved) > Self.sustain { hotSince = nil }
        let since = hotSince ?? now
        hotSince = since
        guard armed,
              now.timeIntervalSince(since) >= Self.sustain,
              lastAlert.map({ now.timeIntervalSince($0) >= Self.cooldown }) ?? true
        else { return false }
        armed = false
        lastAlert = now
        return true
    }
}

enum HeatAlertMessage {
    static let title = "Your Mac is running hot"

    static func body(celsius: Double?, unit: TemperatureUnit, thermalState: ProcessInfo.ThermalState, culprit: ProcessLoad?) -> String {
        let throttled = thermalState == .serious || thermalState == .critical
        let heat = switch (celsius, throttled) {
        case let (celsius?, true): "CPU \(Format.degrees(celsius, unit: unit)), and macOS is slowing your Mac down to cool it off."
        case let (celsius?, false): "CPU \(Format.degrees(celsius, unit: unit))."
        case (nil, _): "macOS is slowing your Mac down to cool it off."
        }
        guard let culprit else { return heat }
        return "\(heat) \(culprit.name) is using the most CPU (\(Int(culprit.percent.rounded()))%)."
    }
}

/// Sends a heat alert when the trigger fires, naming the process using the most CPU at that moment.
@MainActor
final class HeatAlerts {
    static let settingKey = "heatAlerts"
    static let notificationID = "heat"
    /// Long enough for `ps` CPU times to separate a busy process from an idle one.
    private static let sampleGap: Duration = .seconds(2)

    private var trigger = HeatAlertTrigger()
    private var sending = false

    func observe(celsius: Double?, thermalState: ProcessInfo.ThermalState) {
        guard trigger.observe(celsius: celsius, thermalState: thermalState, at: .now),
              UserDefaults.standard.string(forKey: Self.settingKey) != HeatAlertsSetting.off.rawValue,
              !sending
        else { return }
        sending = true
        let unit = UserDefaults.standard.string(forKey: "temperatureUnit").flatMap(TemperatureUnit.init(rawValue:)) ?? .system
        Task {
            defer { sending = false }
            let culprit = await Self.topProcess()
            let center = UNUserNotificationCenter.current()
            // Permission is asked only once there is something to announce.
            guard (try? await center.requestAuthorization(options: [.alert])) == true,
                  UserDefaults.standard.string(forKey: Self.settingKey) != HeatAlertsSetting.off.rawValue
            else { return }
            let content = UNMutableNotificationContent()
            content.title = HeatAlertMessage.title
            content.body = HeatAlertMessage.body(celsius: celsius, unit: unit, thermalState: thermalState, culprit: culprit)
            try? await center.add(UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: nil))
        }
    }

    /// Two `ps` snapshots a moment apart, off the main actor; sampling runs only when an alert fires.
    nonisolated private static func topProcess() async -> ProcessLoad? {
        guard let first = await Task.detached(priority: .utility, operation: { ProcessSampler.snapshot() }).value else { return nil }
        try? await Task.sleep(for: sampleGap)
        guard let second = await Task.detached(priority: .utility, operation: { ProcessSampler.snapshot() }).value,
              second.uptimeNanoseconds > first.uptimeNanoseconds
        else { return nil }
        let percents = ProcessSampler.percents(previous: first.times, current: second.times, elapsedNanoseconds: second.uptimeNanoseconds - first.uptimeNanoseconds)
        return ProcessSampler.ranked(percents).first
    }
}
