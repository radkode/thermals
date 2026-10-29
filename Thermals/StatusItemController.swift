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
    private let defaults: UserDefaults
    private var imageKey: MenuBarImageKey?
    private(set) var shortcut: GlobalShortcut?

    init(monitor: Monitor, updater: Updater, registersShortcut: Bool = true, defaults: UserDefaults = .standard) {
        self.monitor = monitor
        self.updater = updater
        self.defaults = defaults
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
        let mode = MenuBarItem(rawValue: defaults.string(forKey: "menuBarItem") ?? "") ?? .temperature
        let unit = TemperatureUnit(rawValue: defaults.string(forKey: "temperatureUnit") ?? "") ?? .system
        let temperatureStale = monitor.temperatureState.isStale(at: now, interval: monitor.rate.seconds)
        let loadStale = monitor.cpuState.isStale(at: now, interval: monitor.rate.seconds)
        let label = MenuBarReading(item: mode, unit: unit, temperature: temperatureStale ? nil : monitor.cpuTemperature,
                                   load: loadStale ? nil : monitor.cpuLoad, thermalState: monitor.thermalState,
                                   trend: temperatureStale ? nil : TemperatureTrend(monitor.history, now: now),
                                   stale: (mode != .load && temperatureStale) || (mode != .temperature && loadStale))
        let scheme: ColorScheme = button.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
        let scale = button.window?.backingScaleFactor ?? 2
        let key = MenuBarImageKey(reading: label, scheme: scheme, scale: scale, textScale: NSScreen.main?.backingScaleFactor ?? 2)
        if imageKey != key {
            let renderer = ImageRenderer(content: label.environment(\.colorScheme, scheme))
            renderer.scale = scale
            if let image = renderer.nsImage {
                image.isTemplate = false
                button.image = image
                imageKey = key
            }
        }
        button.setAccessibilityLabel(label.accessibilityText)
        button.toolTip = label.accessibilityText
    }
}

struct MenuBarImageKey: Equatable {
    struct Part: Equatable {
        let text: String
        let level: HeatLevel
    }

    let parts: [Part]
    let scheme: ColorScheme
    let scale: CGFloat
    let textScale: CGFloat

    @MainActor init(reading: MenuBarReading, scheme: ColorScheme, scale: CGFloat, textScale: CGFloat) {
        parts = reading.parts.map { Part(text: $0.0, level: $0.1) }
        self.scheme = scheme
        self.scale = scale
        self.textScale = textScale
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
