import ServiceManagement
import SwiftUI
import UserNotifications

// A content-sized departure board; only screen overflow scrolls, with navigation and actions outside.
struct PopoverView: View {
    let monitor: Monitor
    var updater: Updater?
    var shortcut: GlobalShortcut?
    var closePanel: (() -> Void)?
    var panelIsVisible = true
    var pinnedBoard: BoardKind?
    var pinnedUnit: TemperatureUnit?
    var previewLoginError = false
    var previewSettings = false
    var previewLoginPending = false
    var previewNotification: NotificationAccess = .allowed
    var previewAlerts = HeatAlertsSetting.on
    var previewHeight: CGFloat = 768
    var previewDate: Date = PreviewMonitors.referenceDate

    @AppStorage("board") private var storedBoard = BoardKind.heat
    @AppStorage("menuBarItem") private var menuBarItem = MenuBarItem.temperature
    @AppStorage("temperatureUnit") private var temperatureUnit = TemperatureUnit.system
    @AppStorage(HeatAlerts.settingKey) private var heatAlerts = HeatAlertsSetting.on
    @State private var launchStatus = SMAppService.Status.notRegistered
    @State private var loginError = false
    @State private var showsSettings = false
    @State private var notificationAccess = NotificationAccess.checking
    @State private var notificationError = false
    @State private var screenHeight: CGFloat = 800
    @Environment(\.snapshotRendering) private var snapshotRendering

    private var board: BoardKind { pinnedBoard ?? storedBoard }
    private var preview: Bool { pinnedBoard != nil }
    private var settingsOpen: Bool { preview ? previewSettings : showsSettings }
    private var alerts: HeatAlertsSetting { preview ? previewAlerts : heatAlerts }
    private var notification: NotificationAccess { preview ? previewNotification : notificationAccess }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = preview ? previewDate : context.date
            let height = preview ? previewHeight : Board.panelHeight(available: screenHeight)
            ViewThatFits(in: .vertical) {
                shell(at: now) { content }
                    .fixedSize(horizontal: false, vertical: true)
                shell(at: now) { viewport }
                    .frame(height: height)
            }
            .frame(width: Board.popoverWidth)
            .frame(maxHeight: height)
            .fixedSize(horizontal: false, vertical: true)
            .background(Board.steelFrame)
            .environment(\.colorScheme, .dark)
            .environment(\.temperatureUnit, pinnedUnit ?? temperatureUnit)
            .environment(\.readingDate, now)
            .environment(\.sampleInterval, monitor.rate.seconds)
            .background {
                if !preview { PanelScreenReader { screenHeight = $0 }.frame(width: 0, height: 0) }
            }
        }
        .onAppear { updateSampling() }
        .onChange(of: board) { _, _ in updateSampling() }
        .onChange(of: showsSettings) { _, _ in updateSampling() }
        .onChange(of: panelIsVisible) { _, _ in updateSampling() }
        .onDisappear { sample(nil) }
        .task { await refreshPermissions() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await refreshPermissions() }
        }
        .onExitCommand {
            if showsSettings { showsSettings = false }
            else if let closePanel { closePanel() }
            else { NSApp.keyWindow?.orderOut(nil) }
        }
    }

    private func shell(at now: Date, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            FlapTabs(selection: Binding(get: { board }, set: { storedBoard = $0; showsSettings = false }), shortcuts: true, noun: "board")
            content()
            if let version = updater?.available { updateRow(version) }
            footer(at: now)
        }
        .padding(14)
    }

    private var viewport: some View {
        GeometryReader { geometry in
            if snapshotRendering {
                content
                    .frame(width: geometry.size.width, alignment: .topLeading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: geometry.size.height, alignment: .top)
                    .clipped()
            } else {
                ScrollView(.vertical) {
                    content.frame(maxWidth: .infinity, alignment: .leading)
                }
                .id("\(board.rawValue)-\(settingsOpen)")
            }
        }
    }

    @ViewBuilder private var content: some View {
        if settingsOpen { settings }
        else {
            switch board {
            case .heat: HeatBoard(monitor: monitor) { storedBoard = .cpu }
            case .cpu: CPUBoard(monitor: monitor)
            case .ram: RAMBoard(monitor: monitor)
            }
        }
    }

    private var settings: some View {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                ColumnLabel("SETTINGS")
                Spacer()
                ColumnLabel("v\(version) (\(build))")
                    .accessibilityLabel("Thermals version \(version), build \(build)")
                    .help("The version and build of Thermals currently running.")
            }
            HStack {
                ColumnLabel("MENU BAR")
                Spacer()
                FlapTabs(selection: Binding(get: { preview ? .temperature : menuBarItem }, set: { menuBarItem = $0 }), noun: "in menu bar")
            }
            HStack {
                ColumnLabel("TEMPERATURE")
                Spacer()
                FlapTabs(selection: Binding(get: { pinnedUnit ?? temperatureUnit }, set: { temperatureUnit = $0 }), noun: "temperature unit")
            }
            if let shortcut {
                HStack {
                    ColumnLabel("CTRL + OPTION")
                    Spacer()
                    FlapTabs(selection: Binding(get: { shortcut.selected }, set: { shortcut.set($0) }), noun: "global shortcut key")
                }
                BoardNote(shortcut.error ?? "The global shortcut opens or closes Thermals from any app.")
            }
            HStack {
                ColumnLabel("UPDATE EVERY")
                Spacer()
                FlapTabs(selection: Binding(get: { preview ? .six : monitor.rate }, set: { monitor.rate = $0 }), noun: "update interval")
            }
            HStack {
                ColumnLabel("HEAT ALERTS")
                Spacer()
                FlapTabs(selection: Binding(get: { alerts }, set: { heatAlerts = $0 }), noun: "heat alerts")
            }
            BoardNote("Alerts after 30 seconds at 85°C or serious thermal pressure, at most once per episode and ten minutes apart.")
            if alerts == .on {
                BoardNote(notification.message)
                if notification == .notRequested {
                    FlapButton(title: "ALLOW", accessibilityName: "Allow heat alert notifications") {
                        Task {
                            do { _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) }
                            catch { notificationError = true }
                            await refreshPermissions()
                        }
                    }
                } else if notification == .denied {
                    FlapButton(title: "SETTINGS", accessibilityName: "Open macOS notification settings") { NotificationAccess.openSettings() }
                }
                if notificationError { BoardNote("Notification permission could not be requested. Open System Settings, Notifications, Thermals.") }
            }
            HStack {
                ColumnLabel("LAUNCH AT LOGIN")
                Spacer()
                FlapTabs(selection: Binding(get: { preview ? .off : LaunchAtLogin(status: launchStatus) }, set: {
                    let change = LaunchAtLogin.set($0)
                    launchStatus = SMAppService.mainApp.status
                    loginError = change.failed
                }), noun: "launch at login")
            }
            if launchStatus == .requiresApproval || previewLoginPending {
                BoardNote("Approval pending. Thermals will not launch at login until you allow it in System Settings.")
                loginSettingsButton
            }
            if loginError || previewLoginError {
                BoardNote("Login item change failed. Check Login Items in System Settings, then try again.")
                loginSettingsButton
            }
            BoardNote("Temperature bands are reference ranges. CPU and app memory labels describe utilization, not overheating. OS pressure reports system strain.")
        }
    }

    private var loginSettingsButton: some View {
        FlapButton(title: "SETTINGS", accessibilityName: "Open Login Items in System Settings") { LaunchAtLogin.openSettings() }
    }

    private func updateRow(_ version: String) -> some View {
        HStack {
            ColumnLabel("NEW VERSION")
            Spacer()
            FlapText(text: version, cells: min(10, version.count))
            FlapButton(title: "INSTALL", accessibilityName: "Install Thermals \(version)") { updater?.install() }
        }
    }

    private func footer(at now: Date) -> some View {
        HStack(spacing: 10) {
            Text(freshness(at: now))
                .font(Board.labelFont(12))
                .foregroundStyle(Board.steelLight)
                .help("Age of the last successful reading on this board. Each source reports its own failures.")
            Spacer(minLength: 0)
            FlapButton(title: settingsOpen ? "BACK" : "SETTINGS", accessibilityName: settingsOpen ? "Back to readings" : "Open Thermals settings") {
                showsSettings.toggle()
            }
            .keyboardShortcut(",", modifiers: .command)
            QuitButton()
        }
    }

    private func freshness(at now: Date) -> String {
        if settingsOpen { return "⌘, SETTINGS" }
        let state = switch board {
        case .heat: monitor.temperatureState
        case .cpu: monitor.cpuState
        case .ram: monitor.memoryState
        }
        guard let date = state.sampledAt else { return state == .loading ? "WAITING" : "UNAVAILABLE" }
        let age = max(0, Int(now.timeIntervalSince(date)))
        return state.isStale(at: now, interval: monitor.rate.seconds) ? "STALE \(age)S" : "READ \(age)S AGO"
    }

    private func refreshPermissions() async {
        guard !preview else { return }
        launchStatus = SMAppService.mainApp.status
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationAccess = NotificationAccess(status: settings.authorizationStatus, alertsEnabled: settings.alertSetting == .enabled)
        if notificationAccess == .allowed { notificationError = false }
    }

    private func updateSampling() { sample(settingsOpen || !panelIsVisible ? nil : board) }
    private func sample(_ board: BoardKind?) {
        guard !preview else { return }
        monitor.samplesProcesses = board == .cpu
        monitor.samplesHeatActivity = board == .heat
        monitor.samplesAppMemory = board == .ram
    }
}

private struct PanelScreenReader: NSViewRepresentable {
    let onHeight: (CGFloat) -> Void
    func makeNSView(context: Context) -> Probe { Probe(onHeight: onHeight) }
    func updateNSView(_ view: Probe, context: Context) { view.report() }

    final class Probe: NSView {
        let onHeight: (CGFloat) -> Void
        private var lastHeight: CGFloat?
        init(onHeight: @escaping (CGFloat) -> Void) { self.onHeight = onHeight; super.init(frame: .zero) }
        required init?(coder: NSCoder) { nil }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); report() }
        func report() {
            guard let height = window?.screen?.visibleFrame.height, height != lastHeight else { return }
            lastHeight = height
            DispatchQueue.main.async { [weak self] in self?.onHeight(height) }
        }
    }
}
