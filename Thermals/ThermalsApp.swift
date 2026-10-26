import SwiftUI

@main
struct ThermalsApp: App {
    @State private var monitor = Monitor()
    @AppStorage("menuBarItem") private var menuBarItem = MenuBarItem.temperature

    var body: some Scene {
        MenuBarExtra {
            PopoverView(monitor: monitor)
        } label: {
            MenuBarReading(
                item: menuBarItem,
                temperature: monitor.cpuTemperature.map { ($0, monitor.menuBarLevel ?? HeatLevel(celsius: $0.rounded())) },
                load: monitor.cpuLoad.map { ($0, HeatLevel(loadPercent: ($0 * 100).rounded())) }
            )
        }
        .menuBarExtraStyle(.window)
    }
}

/// The chosen reading(s), each colored from the same heat gradient as the popover.
private struct MenuBarReading: View {
    let item: MenuBarItem
    let temperature: (celsius: Double, level: HeatLevel)?
    let load: (fraction: Double, level: HeatLevel)?

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if let text, let image = tinted(text) {
            Image(nsImage: image)
                .accessibilityLabel(accessibilityText)
        } else {
            Image(systemName: "thermometer.medium")
        }
    }

    private var parts: [(String, HeatLevel)] {
        let temp = temperature.map { (Format.degrees($0.celsius), $0.level) }
        let cpu = load.map { (Format.percent($0.fraction), $0.level) }
        return switch item {
        case .temperature: [temp].compactMap { $0 }
        case .load: [cpu].compactMap { $0 }
        case .both: [temp, cpu].compactMap { $0 }
        }
    }

    private var text: Text? {
        let pieces = parts.map { Text($0.0).foregroundStyle(Board.heat($0.1, scheme: scheme)) }
        guard let first = pieces.first else { return nil }
        return pieces.dropFirst().reduce(first) { $0 + Text(" ") + $1 }
    }

    private var accessibilityText: String {
        [temperature.map { "CPU \(Format.degrees($0.celsius))" }, load.map { "load \(Format.percent($0.fraction))" }]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    // Menu bar text is rendered as a template; a pre-rendered non-template image keeps its color.
    @MainActor private func tinted(_ text: Text) -> NSImage? {
        let renderer = ImageRenderer(content: text.font(.system(size: 13, weight: .semibold)).monospacedDigit())
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = false
        return image
    }
}
