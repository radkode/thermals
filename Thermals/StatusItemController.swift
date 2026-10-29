import AppKit
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    let monitor: Monitor
    let updater: Updater
    let popover = NSPopover()
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var timer: Timer?
    private var previousApplication: NSRunningApplication?
    private(set) var shortcut: GlobalShortcut?

    init(monitor: Monitor, updater: Updater, registersShortcut: Bool = true) {
        self.monitor = monitor
        self.updater = updater
        super.init()
        if registersShortcut { shortcut = GlobalShortcut { [weak self] in self?.toggle() } }
        let host = NSHostingController(rootView: PopoverView(monitor: monitor, updater: updater, shortcut: shortcut,
                                                           closePanel: { [weak self] in self?.close() }, panelIsVisible: false))
        host.sizingOptions = [.minSize, .maxSize, .preferredContentSize]
        host.view.setFrameSize(host.view.fittingSize)
        popover.contentViewController = host
        popover.contentSize = host.view.fittingSize
        popover.behavior = .transient
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.animates = false
        popover.delegate = self
        item.autosaveName = "Thermals"
        item.button?.target = self
        item.button?.action = #selector(toggle)
        updateLabel()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateLabel() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    @objc func toggle() {
        if popover.isShown { close(); return }
        guard let button = item.button, button.window != nil else { return }
        previousApplication = NSWorkspace.shared.frontmostApplication
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate()
        popover.contentViewController?.view.window?.makeKey()
    }

    func close() {
        popover.performClose(nil)
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            previousApplication?.activate()
        }
    }

    func popoverDidShow(_ notification: Notification) {
        (popover.contentViewController as? NSHostingController<PopoverView>)?.rootView.panelIsVisible = true
    }

    func popoverDidClose(_ notification: Notification) {
        (popover.contentViewController as? NSHostingController<PopoverView>)?.rootView.panelIsVisible = false
        monitor.samplesProcesses = false
        monitor.samplesHeatActivity = false
        monitor.samplesAppMemory = false
    }

    func stop() {
        popover.close()
        timer?.invalidate()
        shortcut?.stop()
        NSStatusBar.system.removeStatusItem(item)
    }

    func updateLabel(at now: Date = .now) {
        guard let button = item.button else { return }
        let defaults = UserDefaults.standard
        let mode = MenuBarItem(rawValue: defaults.string(forKey: "menuBarItem") ?? "") ?? .temperature
        let unit = TemperatureUnit(rawValue: defaults.string(forKey: "temperatureUnit") ?? "") ?? .system
        let temperatureStale = monitor.temperatureState.isStale(at: now, interval: monitor.rate.seconds)
        let loadStale = monitor.cpuState.isStale(at: now, interval: monitor.rate.seconds)
        let label = MenuBarReading(item: mode, unit: unit, temperature: temperatureStale ? nil : monitor.cpuTemperature,
                                   load: loadStale ? nil : monitor.cpuLoad, thermalState: monitor.thermalState,
                                   trend: temperatureStale ? nil : TemperatureTrend(monitor.history, now: now),
                                   stale: (mode != .load && temperatureStale) || (mode != .temperature && loadStale))
        let scheme: ColorScheme = button.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
        let renderer = ImageRenderer(content: label.environment(\.colorScheme, scheme))
        renderer.scale = button.window?.backingScaleFactor ?? 2
        if let image = renderer.nsImage { image.isTemplate = false; button.image = image }
        button.setAccessibilityLabel(label.accessibilityText)
        button.toolTip = label.accessibilityText
    }
}

@MainActor
final class ThermalsDelegate: NSObject, NSApplicationDelegate {
    private var status: StatusItemController?
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        status = StatusItemController(monitor: Monitor(), updater: Updater())
    }
    func applicationWillTerminate(_ notification: Notification) { status?.stop() }
}
