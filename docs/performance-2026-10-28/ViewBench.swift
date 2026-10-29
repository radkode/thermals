import AppKit
import Foundation
import SwiftUI

@main @MainActor struct ViewBench {
    static func main() throws {
        _ = NSApplication.shared
        for name in ["BarlowCondensed-Medium", "BarlowCondensed-SemiBold"] {
            CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent(name + ".ttf") as CFURL, .process, nil)
        }
        guard let directory = ProcessInfo.processInfo.environment["PERF_OUTPUT"] else { return }
        var rows: [[String: Any]] = []
        func measure<T>(_ name: String, count: Int = 15, _ action: () throws -> T) rethrows {
            var times: [Double] = []
            for _ in 0..<count {
                let start = DispatchTime.now().uptimeNanoseconds
                try autoreleasepool { withExtendedLifetime(try action()) {} }
                times.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6)
            }
            let sorted = times.sorted()
            rows.append(["name": name, "n": count, "wall_ms": times, "median_ms": sorted[count / 2],
                         "p95_ms": sorted[Int(ceil(Double(count) * 0.95)) - 1], "max_ms": sorted.last!])
        }
        let monitor = PreviewMonitors.hot()
        let large = PreviewMonitors.largeMachine()
        measure("preview monitor initialization", count: 10) { PreviewMonitors.hot() }
        measure("refresh without footprints", count: 30) { monitor.refresh() }
        monitor.samplesAppMemory = true
        measure("refresh with footprints", count: 30) { monitor.refresh() }
        monitor.samplesAppMemory = false
        let fixture = PreviewMonitors.hot()
        func render(_ view: some View) throws -> CGImage {
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.cgImage else { throw NSError(domain: "Render", code: 1) }; return image
        }
        for board in BoardKind.allCases {
            try measure("cold image render \(board.rawValue)") {
                try render(PopoverView(monitor: fixture, pinnedBoard: board, previewHeight: 736)
                    .environment(\.snapshotRendering, true))
            }
        }
        try measure("cold image render CPU 48 cores") {
            try render(PopoverView(monitor: large, pinnedBoard: .cpu, previewHeight: 736)
                .environment(\.snapshotRendering, true))
        }
        try measure("cold image render settings") {
            try render(PopoverView(monitor: fixture, pinnedBoard: .heat, previewSettings: true)
                .environment(\.snapshotRendering, true))
        }
        try measure("menu image body", count: 100) {
            try render(MenuBarReading(item: .both, unit: .celsius, temperature: 72, load: 0.45, thermalState: .nominal, trend: .rising))
        }
        measure("history bucketing", count: 1000) { LampMeter.columnPeaks(fixture.history, now: PreviewMonitors.referenceDate) }
        measure("temperature trend", count: 1000) { TemperatureTrend(fixture.history, now: PreviewMonitors.referenceDate) }
        let data = try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("view-probes.json"))
    }
}

@MainActor @Observable final class Updater { var available: String?; init(previewing version: String) { available = version }; func install() {} }
