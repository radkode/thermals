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
        let states: [(String, Monitor)] = [
            ("cool", PreviewMonitors.cool()),
            ("hot", PreviewMonitors.hot()),
            ("no-sensors", PreviewMonitors.noSensors()),
        ]
        for (name, monitor) in states {
            let renderer = ImageRenderer(content: PopoverView(monitor: monitor))
            renderer.scale = 2
            let image = try #require(renderer.cgImage)
            let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: Self.directory!).appendingPathComponent("popover-\(name).png"))
        }
    }
}
