import AppKit
import Foundation
import SwiftUI
import Testing
@testable import Thermals

/// Writes popover renders for design review. Opt in: `TEST_RUNNER_SNAPSHOT_DIR=<dir> xcodebuild ... test`.
@MainActor
struct PopoverSnapshotTests {
    nonisolated static let directory = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"]

    @Test(.enabled(if: directory != nil))
    func renderStates() throws {
        let states: [(String, Monitor, BoardKind)] = [
            ("cool", PreviewMonitors.cool(), .heat),
            ("hot", PreviewMonitors.hot(), .heat),
            ("no-sensors", PreviewMonitors.noSensors(), .heat),
            ("cpu-cool", PreviewMonitors.cool(), .cpu),
            ("cpu-hot", PreviewMonitors.hot(), .cpu),
            ("ram-cool", PreviewMonitors.cool(), .ram),
            ("ram-hot", PreviewMonitors.hot(), .ram),
            ("ram-unavailable", PreviewMonitors.noSensors(), .ram),
            ("hot-fahrenheit", PreviewMonitors.hot(), .heat),
            ("update-available", PreviewMonitors.cool(), .heat),
        ]
        for (name, monitor, board) in states {
            let unit: TemperatureUnit = name.hasSuffix("fahrenheit") ? .fahrenheit : .celsius
            let renderer = ImageRenderer(content: PopoverView(monitor: monitor, updater: name.hasPrefix("update") ? Updater(previewing: "0.3.0") : nil, pinnedBoard: board, pinnedUnit: unit).environment(\.snapshotRendering, true))
            renderer.scale = 2
            let image = try #require(renderer.cgImage)
            let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: Self.directory!).appendingPathComponent("popover-\(name).png"))
        }
    }
}
