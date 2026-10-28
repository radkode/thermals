import AppKit
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

/// Decides when heat is worth a notification: `thresholdCelsius` or serious thermal pressure held for `sustain`, once per episode.
/// An episode ends only when the Mac cools below HOT, and alerts stay at least `cooldown` apart.
struct HeatAlertTrigger {
    /// Below BURN's 90°C: fan-cooled Macs rarely reach BURN even at full load.
    static let thresholdCelsius = 85.0
    static let sustain: TimeInterval = 30
    static let cooldown: TimeInterval = 600

    private var hotSince: Date?
    private var lastObserved: Date?
    private var lastAlert: Date?
    private var armed = true

    /// True when this reading should raise an alert.
    mutating func observe(celsius: Double?, thermalState: ProcessInfo.ThermalState, at now: Date) -> Bool {
        defer { lastObserved = now }
        let hot = celsius.map { $0.rounded() >= Self.thresholdCelsius } ?? false
        let throttled = thermalState == .serious || thermalState == .critical
        guard hot || throttled else {
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

    private var trigger = HeatAlertTrigger()
    private var sending = false

    func observe(celsius: Double?, thermalState: ProcessInfo.ThermalState) {
        guard trigger.observe(celsius: celsius, thermalState: thermalState, at: .now),
              UserDefaults.standard.string(forKey: Self.settingKey) != HeatAlertsSetting.off.rawValue
        else { return }
        send(celsius: celsius, thermalState: thermalState)
    }

    func send(celsius: Double?, thermalState: ProcessInfo.ThermalState) {
        guard !sending else { return }
        sending = true
        let unit = UserDefaults.standard.string(forKey: "temperatureUnit").flatMap(TemperatureUnit.init(rawValue:)) ?? .system
        Task {
            defer { sending = false }
            let culprit = await ProcessSampler.busiest()
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
}

/// Requested alerts and macOS delivery authorization are separate states.
enum NotificationAccess: Equatable {
    case checking, notRequested, allowed, denied

    init(status: UNAuthorizationStatus, alertsEnabled: Bool) {
        switch status {
        case .notDetermined: self = .notRequested
        case .authorized, .provisional: self = alertsEnabled ? .allowed : .denied
        default: self = .denied
        }
    }

    var message: String {
        switch self {
        case .checking: "Checking macOS notification permission…"
        case .notRequested: "Permission needed. Allow notifications now, or macOS will ask at the first heat alert."
        case .allowed: "Notifications allowed by macOS. Focus settings can still silence them."
        case .denied: "Heat alerts are requested, but macOS notifications are blocked. Enable Thermals in Notifications settings."
        }
    }

    @MainActor static func openSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
    }
}
