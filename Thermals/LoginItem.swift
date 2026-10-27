import ServiceManagement

/// Launch at login, backed by `SMAppService.mainApp`. The system owns the state, so it is read back rather than stored.
enum LaunchAtLogin: String, FlapTabOption {
    case on, off

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

    /// Registers or unregisters, then returns what the system reports, so a refused change shows as unchanged.
    @MainActor static func set(_ choice: LaunchAtLogin) -> LaunchAtLogin {
        let service = SMAppService.mainApp
        try? choice == .on ? service.register() : service.unregister()
        if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        return current
    }
}
