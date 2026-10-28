import os
import ServiceManagement

/// Launch at login, backed by `SMAppService.mainApp`. The system owns the state, so it is read back rather than stored.
enum LaunchAtLogin: String, FlapTabOption {
    case on, off

    private static let logger = Logger(subsystem: "com.radkode.thermals", category: "LoginItem")

    var title: String {
        switch self {
        case .on: "ON"
        case .off: "OFF"
        }
    }

    /// Only an approved item launches. Awaiting approval, including after the user turns it off in System Settings, reads as off.
    init(status: SMAppService.Status) {
        self = status == .enabled ? .on : .off
    }

    @MainActor static var current: LaunchAtLogin { LaunchAtLogin(status: SMAppService.mainApp.status) }

    @MainActor static func openSettings() { SMAppService.openSystemSettingsLoginItems() }

    /// Registers or unregisters, then returns what the system reports, so a refused change shows as unchanged.
    @MainActor static func set(_ choice: LaunchAtLogin) -> (state: LaunchAtLogin, failed: Bool) {
        let service = SMAppService.mainApp
        var failed = false
        do {
            if choice == .on { try service.register() } else { try service.unregister() }
        } catch {
            logger.error("Launch at login \(choice.rawValue, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            failed = true
        }
        if service.status == .requiresApproval { openSettings() }
        return (current, failed)
    }
}
