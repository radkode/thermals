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
        ]
        for (name, monitor, board) in states {
            let renderer = ImageRenderer(content: PopoverView(monitor: monitor, pinnedBoard: board).environment(\.snapshotRendering, true))
            renderer.scale = 2
            let image = try #require(renderer.cgImage)
            let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: Self.directory!).appendingPathComponent("popover-\(name).png"))
        }
    }
}
