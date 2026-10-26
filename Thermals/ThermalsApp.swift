import SwiftUI

@main
struct ThermalsApp: App {
    @State private var monitor = Monitor()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(monitor: monitor)
        } label: {
            MenuBarReading(celsius: monitor.cpuTemperature, band: monitor.menuBarBand)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Monochrome like every other menu bar item until the Mac runs hot, then the reading takes the heat color.
private struct MenuBarReading: View {
    let celsius: Double?
    let band: HeatBand?

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if let celsius, let band, band >= .hot, let image = tinted(Format.degrees(celsius), band: band) {
            Image(nsImage: image)
        } else if let celsius {
            Text(Format.degrees(celsius))
        } else {
            Image(systemName: "thermometer.medium")
        }
    }

    // Menu bar text is rendered as a template; a pre-rendered non-template image keeps its color.
    @MainActor private func tinted(_ text: String, band: HeatBand) -> NSImage? {
        let renderer = ImageRenderer(
            content: Text(text)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Board.menuBarInk(for: band, scheme: scheme))
        )
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = false
        return image
    }
}
