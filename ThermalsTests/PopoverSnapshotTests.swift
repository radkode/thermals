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
    func boardsFitWithPersistentScrollbars() throws {
        let monitor = PreviewMonitors.largeMachine()
        for (name, board) in [("heat", AnyView(HeatBoard(monitor: monitor))), ("cpu", AnyView(CPUBoard(monitor: monitor))), ("ram", AnyView(RAMBoard(monitor: PreviewMonitors.hot())))] {
            let renderer = ImageRenderer(content: board.environment(\.readingDate, PreviewMonitors.referenceDate))
            renderer.proposedSize = ProposedViewSize(width: 356, height: nil)
            renderer.scale = 2
            let image = try #require(renderer.cgImage)
            #expect(image.width <= 712, "\(name) must fit after reserving 16 points for a persistent scrollbar")
            let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: Self.directory!).appendingPathComponent("narrow-\(name).png"))
        }
    }

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
            ("login-error", PreviewMonitors.cool(), .heat),
            ("settings", PreviewMonitors.cool(), .heat),
            ("settings-denied", PreviewMonitors.cool(), .heat),
            ("settings-permission-needed", PreviewMonitors.cool(), .heat),
            ("settings-off", PreviewMonitors.cool(), .heat),
            ("settings-denied-off", PreviewMonitors.cool(), .heat),
            ("settings-permission-needed-off", PreviewMonitors.cool(), .heat),
            ("login-pending", PreviewMonitors.cool(), .heat),
            ("compact", PreviewMonitors.cool(), .heat),
            ("large-cores", PreviewMonitors.largeMachine(), .cpu),
            ("long-names", PreviewMonitors.largeMachine(), .heat),
            ("stale", PreviewMonitors.stale(), .heat),
            ("cpu-unavailable", PreviewMonitors.noSensors(), .cpu),
            ("cpu-initial", PreviewMonitors.initialCPU(), .cpu),
            ("cpu-empty", PreviewMonitors.emptyProcesses(), .cpu),
            ("low-temperature-critical", PreviewMonitors.lowTemperatureCritical(), .heat),
            ("no-temperature-critical", PreviewMonitors.missingTemperatureCritical(), .heat),
            ("ram-high-normal", PreviewMonitors.lowTemperatureCritical(), .ram),
        ]
        for (name, monitor, board) in states {
            let unit: TemperatureUnit = name.hasSuffix("fahrenheit") ? .fahrenheit : .celsius
            let height: CGFloat = name == "compact" ? 520 : 640
            let view = PopoverView(
                monitor: monitor, updater: name.hasPrefix("update") ? Updater(previewing: "0.3.3") : nil,
                pinnedBoard: board, pinnedUnit: unit, previewLoginError: name == "login-error",
                previewSettings: name.hasPrefix("settings") || name.hasPrefix("login"),
                previewLoginPending: name == "login-pending",
                previewNotification: name.hasPrefix("settings-denied") ? .denied : name.hasPrefix("settings-permission-needed") ? .notRequested : .allowed,
                previewAlerts: name.hasSuffix("-off") ? .off : .on,
                previewHeight: height
            ).environment(\.snapshotRendering, true)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            let image = try #require(renderer.cgImage)
            #expect(image.width == 800)
            #expect(image.height == Int(height * 2))
            let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: Self.directory!).appendingPathComponent("popover-\(name).png"))
        }
    }
}
