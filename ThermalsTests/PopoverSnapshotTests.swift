import AppKit
import Foundation
import SwiftUI
import Testing
@testable import Thermals

/// Writes popover renders for design review. Opt in: `TEST_RUNNER_SNAPSHOT_DIR=<dir> xcodebuild ... test`.
@MainActor
struct PopoverSnapshotTests {
    nonisolated static let directory = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"]

    @Test func panelRejectsExcessHeightProposals() throws {
        for board in BoardKind.allCases {
            for settings in [false, true] {
                let view = PopoverView(monitor: PreviewMonitors.hot(), pinnedBoard: board, previewSettings: settings, previewHeight: 736)
                    .environment(\.snapshotRendering, true)
                let renderer = ImageRenderer(content: view)
                let natural = try #require(renderer.cgImage)
                renderer.proposedSize = ProposedViewSize(width: 400, height: 1200)
                let expanded = try #require(renderer.cgImage)
                #expect(expanded.height == natural.height, "Host proposals must not stretch \(board), settings \(settings)")
                #expect(expanded.dataProvider?.data == natural.dataProvider?.data)
            }
        }
        let overflow = PopoverView(monitor: PreviewMonitors.largeMachine(), pinnedBoard: .cpu, previewHeight: 520)
            .environment(\.snapshotRendering, true)
        let renderer = ImageRenderer(content: overflow)
        renderer.proposedSize = ProposedViewSize(width: 400, height: 1200)
        #expect(try #require(renderer.cgImage).height == 520)
    }

    @Test func historyOutlierDoesNotRecolorEarlierColumns() throws {
        let now = PreviewMonitors.referenceDate
        let readings = [TimedValue(date: now.addingTimeInterval(-174), value: 50), TimedValue(date: now.addingTimeInterval(-168), value: 50)]
        for scale in [MeterScale.percentage, .temperature] {
            func plot(_ values: [TimedValue]) throws -> CGImage {
                let renderer = ImageRenderer(content: LampMeter(readings: values, scale: scale, unit: "%", accessibilityName: "Test")
                    .frame(width: 372).environment(\.readingDate, now))
                let image = try #require(renderer.cgImage)
                return try #require(image.cropping(to: CGRect(x: 40, y: image.height - 54, width: 150, height: 46)))
            }
            let baseline = try plot(readings)
            let outlier = try plot(readings + [TimedValue(date: now, value: 100)])
            #expect(baseline.dataProvider?.data == outlier.dataProvider?.data, "A later outlier must not change the earlier bars")
        }
    }

    @Test func ordinaryBoardsFitWithoutOverflow() throws {
        for board in BoardKind.allCases {
            let monitor = PreviewMonitors.hot()
            let natural = try render(monitor, board: board, height: 2000)
            let laptop = try render(monitor, board: board, height: 736)
            #expect(natural.height < 736, "\(board) must fit on an 800-point desktop after screen margins")
            #expect(laptop.height == natural.height, "\(board) must keep its complete natural layout")
            #expect(laptop.dataProvider?.data == natural.dataProvider?.data)
        }
    }

    @Test func overflowUsesOnlyTheAvailableHeight() throws {
        let monitor = PreviewMonitors.largeMachine()
        let natural = try render(monitor, board: .cpu, height: 2000)
        let bounded = try render(monitor, board: .cpu, height: 736)
        #expect(natural.height > 736)
        #expect(bounded.height == 736)
        let compact = try render(PreviewMonitors.hot(), board: .heat, height: 520)
        #expect(compact.height == 520)
    }

    @Test func tenAppRowsFitOnANineHundredPointDesktop() throws {
        let source = PreviewMonitors.hot()
        let monitor = Monitor(sensors: source.sensors, cpuLoad: source.cpuLoad, thermalState: source.thermalState,
                              history: source.history, memory: source.memory, memoryHistory: source.memoryHistory,
                              appMemory: source.appMemory + (7...10).map { AppMemory(name: "App \($0)", bytes: 100_000_000) })
        let natural = try render(monitor, board: .ram, height: 2000)
        let bounded = try render(monitor, board: .ram, height: 836)
        #expect(natural.height < 836)
        #expect(bounded.dataProvider?.data == natural.dataProvider?.data)
    }

    @Test func nativeHostingResizesAndOnlyScrollsOverflow() async throws {
        let host = NSHostingView(rootView: PopoverView(monitor: PreviewMonitors.hot(), pinnedBoard: .heat))
        let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        defer { window.close() }
        for (monitor, board, height, needsScroll) in [
            (PreviewMonitors.largeMachine(), BoardKind.cpu, 736.0, true),
            (PreviewMonitors.hot(), BoardKind.heat, 736.0, false),
            (PreviewMonitors.hot(), .cpu, 736.0, false),
            (PreviewMonitors.hot(), .ram, 736.0, false),
            (PreviewMonitors.hot(), .heat, 520.0, true),
        ] {
            host.rootView = PopoverView(monitor: monitor, pinnedBoard: board, previewHeight: height)
            window.setContentSize(host.fittingSize)
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(100))
            #expect(host.frame.height <= height)
            if !needsScroll { #expect(host.fittingSize.height < height) }
            let scrolls = scrollViews(in: host).filter { !$0.isHiddenOrHasHiddenAncestor }
            #expect(!scrolls.isEmpty == needsScroll, "\(board) at \(height) points")
            if needsScroll {
                let scroll = try #require(scrolls.first)
                let document = try #require(scroll.documentView)
                #expect(document.frame.height > scroll.contentView.bounds.height)
            }
        }
        host.rootView = PopoverView(monitor: PreviewMonitors.hot(), pinnedBoard: .heat, previewSettings: true, previewHeight: 736)
        window.setContentSize(host.fittingSize)
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        #expect(host.fittingSize.height < 520, "Settings must relinquish the preceding overflow height")
        #expect(scrollViews(in: host).filter { !$0.isHiddenOrHasHiddenAncestor }.isEmpty)
    }

    @Test func nativeWindowShrinksWithoutManualSizing() async throws {
        let controller = NSHostingController(rootView: PopoverView(monitor: PreviewMonitors.largeMachine(), pinnedBoard: .cpu, previewHeight: 736))
        controller.sizingOptions = [.minSize, .maxSize, .preferredContentSize]
        let window = NSWindow(contentViewController: controller)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.setContentSize(NSSize(width: 400, height: 1200))
        window.orderFront(nil)
        try await Task.sleep(for: .milliseconds(100))
        #expect(controller.view.frame.height == 736)
        for board in BoardKind.allCases {
            controller.rootView = PopoverView(monitor: PreviewMonitors.hot(), pinnedBoard: board, previewHeight: 736)
            try await Task.sleep(for: .milliseconds(100))
            #expect(controller.view.frame.height < 736, "\(board) must release the previous overflow height")
            #expect(scrollViews(in: controller.view).filter { !$0.isHiddenOrHasHiddenAncestor }.isEmpty)
        }
        controller.rootView = PopoverView(monitor: PreviewMonitors.hot(), pinnedBoard: .heat, previewSettings: true, previewHeight: 736)
        try await Task.sleep(for: .milliseconds(100))
        #expect(controller.view.frame.height < 520, "Settings must shrink through native sizing constraints")
    }

    private func scrollViews(in view: NSView) -> [NSScrollView] {
        (view as? NSScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
    }

    private func render(_ monitor: Monitor, board: BoardKind, height: CGFloat) throws -> CGImage {
        let view = PopoverView(monitor: monitor, pinnedBoard: board, pinnedUnit: .celsius, previewHeight: height)
            .environment(\.snapshotRendering, true)
        let renderer = ImageRenderer(content: view)
        return try #require(renderer.cgImage)
    }

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
            let height: CGFloat = name == "compact" ? 520 : 768
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
            #expect(image.height <= Int(height * 2))
            let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: Self.directory!).appendingPathComponent("popover-\(name).png"))
        }
    }
}
