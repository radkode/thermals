import SwiftUI

@main
struct ThermalsApp: App {
    @State private var monitor = Monitor()
    @State private var updater = Updater()
    @AppStorage("menuBarItem") private var menuBarItem = MenuBarItem.temperature
    @AppStorage("temperatureUnit") private var temperatureUnit = TemperatureUnit.system
    @State private var readingDate = Date.now

    var body: some Scene {
        MenuBarExtra {
            PopoverView(monitor: monitor, updater: updater)
        } label: {
            let temperatureStale = monitor.temperatureState.isStale(at: readingDate, interval: monitor.rate.seconds)
            let loadStale = monitor.cpuState.isStale(at: readingDate, interval: monitor.rate.seconds)
            MenuBarReading(
                item: menuBarItem,
                unit: temperatureUnit,
                temperature: temperatureStale ? nil : monitor.cpuTemperature,
                load: loadStale ? nil : monitor.cpuLoad,
                thermalState: monitor.thermalState,
                trend: temperatureStale ? nil : TemperatureTrend(monitor.history, now: readingDate),
                stale: (menuBarItem != .load && temperatureStale) || (menuBarItem != .temperature && loadStale)
            )
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { readingDate = $0 }
        }
        .menuBarExtraStyle(.window)
    }
}

/// The chosen reading(s), each colored from the same heat gradient as the popover.
struct MenuBarReading: View {
    let item: MenuBarItem
    let unit: TemperatureUnit
    let temperature: Double?
    let load: Double?
    let thermalState: ProcessInfo.ThermalState
    var trend: TemperatureTrend?
    var stale = false

    /// Barlow Condensed has no arrows, so trend parts are drawn as SF Symbols at its cap height.
    private static let arrowSymbols = ["↑": "arrow.up", "↓": "arrow.down"]

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if let text, let image = tinted(text) {
            Image(nsImage: image)
                .accessibilityLabel(accessibilityText)
        } else {
            Image(systemName: "thermometer.medium")
                .accessibilityLabel(accessibilityText)
        }
    }

    var parts: [(String, HeatLevel)] {
        let level = HeatLevel.menuBar(celsius: temperature?.rounded(), thermalState: thermalState)
        let temp = level.map { (temperature.map { Format.degrees($0, unit: unit) } ?? "--°", $0) }
        let arrow: (String, HeatLevel)? = if temperature != nil, let glyph = trend?.glyph, let level { (glyph, level) } else { nil }
        let cpu = load.map { (Format.percent($0), HeatLevel(loadPercent: ($0 * 100).rounded()).utilization) }
        var values: [(String, HeatLevel)] = switch item {
        case .temperature: [temp, arrow].compactMap { $0 }
        case .load: [cpu].compactMap { $0 }
        case .both: [temp, arrow, cpu].compactMap { $0 }
        }
        if thermalState == .serious || thermalState == .critical, let level {
            values.insert(("!", level), at: 0)
        }
        if stale { values.append(("?", HeatLevel(position: 0))) }
        return values
    }

    private var text: Text? {
        parts.reduce(nil) { text, part in
            let symbol = Self.arrowSymbols[part.0]
            let piece = (symbol.map { Text(Image(systemName: $0)).font(.system(size: 10, weight: .bold)) } ?? Text(part.0))
                .foregroundStyle(Board.heat(part.1, scheme: scheme))
            // The arrow hugs the temperature it qualifies.
            return text.map { $0 + Text(symbol == nil ? " " : "") + piece } ?? piece
        }
    }

    var accessibilityText: String {
        var descriptions = [String]()
        if item != .load {
            descriptions.append(temperature.map { "CPU \(Format.degrees($0, unit: unit))\(trend.map { ", \($0.spoken)" } ?? "")" } ?? "CPU temperature unavailable")
        }
        if item != .temperature {
            descriptions.append(load.map { "whole-system CPU load \(Format.percent($0))" } ?? "CPU load unavailable")
        }
        if stale { descriptions.append("Readings are stale") }
        descriptions.append("Thermal pressure \(thermalState.boardTitle.lowercased())")
        return descriptions.joined(separator: ", ")
    }

    // Menu bar text is rendered as a template; a pre-rendered non-template image keeps its color.
    @MainActor private func tinted(_ text: Text) -> NSImage? {
        // Barlow Condensed runs small for its size; 15pt matches the menu bar's 13pt system cap height.
        let renderer = ImageRenderer(content: text.font(Board.flapFont(15)).tracking(0.4).monospacedDigit())
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = false
        return image
    }
}
