import AppKit
import Foundation
import OSLog
import SwiftUI
import Testing
@testable import Thermals

@MainActor @Suite(.serialized)
struct RenderingPerformanceTests {
    nonisolated static let directory = ProcessInfo.processInfo.environment["PERF_OUTPUT"]

    @Test(.enabled(if: directory != nil))
    func nativeFlapAnimation() async throws {
        let directory = URL(fileURLWithPath: try #require(Self.directory))
        let host = NSHostingView(rootView: FlapCell(character: "8", size: .hero, ink: Board.letterWhite, cascadeIndex: 0).padding(10))
        let window = NSWindow(contentRect: CGRect(x: 100, y: 100, width: 58, height: 78), styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFront(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(100))
        var frames: [Data] = []
        for index in 0..<9 {
            if index == 1 {
                host.rootView = FlapCell(character: "1", size: .hero, ink: Board.letterWhite, cascadeIndex: 0).padding(10)
            }
            if index > 0 { try await Task.sleep(for: .milliseconds(35)) }
            let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            frames.append(png)
            try png.write(to: directory.appendingPathComponent("flap-\(index).png"))
        }
        #expect(frames.first != frames.last)
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            #expect(Set(frames).count > 2, "A native flip must draw intermediate states, not just switch glyphs")
        }
    }

    @Test(.enabled(if: directory != nil))
    func nativeConstructionAndUpdates() async throws {
        let directory = URL(fileURLWithPath: try #require(Self.directory))
        try String(ProcessInfo.processInfo.processIdentifier).write(to: directory.appendingPathComponent("pid.txt"), atomically: true, encoding: .utf8)
        if ProcessInfo.processInfo.environment["PERF_ATTACH"] == "1" { try await Task.sleep(for: .seconds(15)) }
        let signposter = OSSignposter(subsystem: "com.radkode.thermals", category: "RenderingProbe")
        var results: [[String: Any]] = []
        let fixtures: [(String, BoardKind, Monitor)] = [
            ("heat", .heat, PreviewMonitors.hot()), ("cpu", .cpu, PreviewMonitors.hot()),
            ("ram", .ram, PreviewMonitors.hot()), ("cpu48", .cpu, PreviewMonitors.largeMachine())
        ]
        for (name, board, monitor) in fixtures {
            var construction: [Double] = []
            var raster: [Double] = []
            for iteration in 0..<10 {
                let view = PopoverView(monitor: monitor, pinnedBoard: board, pinnedUnit: .celsius, previewHeight: 736)
                let start = DispatchTime.now().uptimeNanoseconds
                let interval = signposter.beginInterval("Board construction")
                let controller = NSHostingController(rootView: view)
                controller.sizingOptions = [.minSize, .maxSize, .preferredContentSize]
                let window = NSWindow(contentViewController: controller)
                window.isReleasedWhenClosed = false
                window.setContentSize(NSSize(width: 400, height: 736))
                window.orderFront(nil)
                controller.view.layoutSubtreeIfNeeded()
                controller.view.displayIfNeeded()
                signposter.endInterval("Board construction", interval)
                construction.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6)
                try await Task.sleep(for: .milliseconds(100))
                #expect(controller.view.frame.width == 400)
                #expect(controller.view.frame.height <= 736)
                window.close()
                let renderer = ImageRenderer(content: view.environment(\.snapshotRendering, true))
                renderer.scale = 2
                let rasterStart = DispatchTime.now().uptimeNanoseconds
                let image = try #require(renderer.cgImage)
                raster.append(Double(DispatchTime.now().uptimeNanoseconds - rasterStart) / 1e6)
                if iteration == 0 {
                    let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
                    try png.write(to: directory.appendingPathComponent("\(name).png"))
                }
            }
            results.append(["board": name, "native_construction_ms": construction, "offscreen_raster_ms": raster])
        }
        let monitor = PreviewMonitors.hot()
        let controller = NSHostingController(rootView: PopoverView(monitor: monitor, pinnedBoard: .cpu, pinnedUnit: .celsius))
        let window = NSWindow(contentViewController: controller)
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 400, height: 736))
        window.orderFront(nil)
        defer { window.close() }
        do {
            var ticks = CPUTicks.zero
            monitor.updateCPU(ticks: Array(repeating: ticks, count: 12), at: .now)
            for index in 0..<32 {
                let interval = signposter.beginInterval("Animated update")
                ticks.user += index.isMultiple(of: 2) ? 90 : 10
                ticks.idle += index.isMultiple(of: 2) ? 10 : 90
                monitor.updateCPU(ticks: Array(repeating: ticks, count: 12), at: .now)
                try await Task.sleep(for: .milliseconds(600))
                signposter.endInterval("Animated update", interval)
            }
        }
        try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("rendering.json"))
    }
}
