import SwiftUI

@main
struct ThermalsApp: App {
    @State private var monitor = Monitor()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(monitor: monitor)
        } label: {
            if let celsius = monitor.cpuTemperature {
                Text(Format.degrees(celsius))
            } else {
                Image(systemName: "thermometer.medium")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
