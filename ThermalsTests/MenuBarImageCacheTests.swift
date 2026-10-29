import AppKit
import SwiftUI
import Testing
@testable import Thermals

@MainActor @Suite(.serialized)
struct MenuBarImageCacheTests {
    @Test(.enabled(if: RenderingPerformanceTests.directory != nil))
    func measureUnchangedMenuUpdates() throws {
        let suite = "Thermals.MenuBenchmark.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(MenuBarItem.both.rawValue, forKey: "menuBarItem")
        defaults.set(TemperatureUnit.celsius.rawValue, forKey: "temperatureUnit")
        let monitor = PreviewMonitors.hot()
        let now = PreviewMonitors.referenceDate
        let controller = StatusItemController(monitor: monitor, updater: Updater(previewing: "0.4.4"), registersShortcut: false, defaults: defaults)
        defer { controller.stop() }
        let button = try #require(controller.item.button)
        controller.updateLabel(at: now)
        let cached = try #require(button.image)
        let label = MenuBarReading(item: .both, unit: .celsius, temperature: monitor.cpuTemperature, load: monitor.cpuLoad,
                                   thermalState: monitor.thermalState, trend: TemperatureTrend(monitor.history, now: now))
        let scheme: ColorScheme = button.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
        func cpuMilliseconds() -> Double {
            var usage = rusage()
            getrusage(RUSAGE_SELF, &usage)
            return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) * 1_000
                + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000
        }
        func measure(_ body: () -> Void) -> [String: Double] {
            let cpu = cpuMilliseconds(), start = DispatchTime.now().uptimeNanoseconds
            for _ in 0..<1_000 { autoreleasepool(invoking: body) }
            return ["cpu_ms": cpuMilliseconds() - cpu, "wall_ms": Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6]
        }
        let reuse = measure { controller.updateLabel(at: now) }
        #expect(button.image === cached)
        var renders = 0
        let fresh = measure {
            let renderer = ImageRenderer(content: label.environment(\.colorScheme, scheme))
            renderer.scale = button.window?.backingScaleFactor ?? 2
            if let image = renderer.nsImage { image.isTemplate = false; button.image = image; renders += 1 }
        }
        #expect(renders == 1_000)
        let directory = URL(fileURLWithPath: try #require(RenderingPerformanceTests.directory))
        try JSONSerialization.data(withJSONObject: ["iterations": 1_000, "cached_update": reuse, "fresh_raster": fresh], options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("menu-cache.json"))
    }

    private func reading(item: MenuBarItem = .both, unit: TemperatureUnit = .celsius, temperature: Double? = 72.1,
                         load: Double? = 0.501, pressure: ProcessInfo.ThermalState = .nominal,
                         trend: TemperatureTrend? = nil, stale: Bool = false) -> MenuBarReading {
        MenuBarReading(item: item, unit: unit, temperature: temperature, load: load, thermalState: pressure, trend: trend, stale: stale)
    }

    private func key(_ reading: MenuBarReading, scheme: ColorScheme = .dark, scale: CGFloat = 2, textScale: CGFloat = 2) -> MenuBarImageKey {
        MenuBarImageKey(reading: reading, scheme: scheme, scale: scale, textScale: textScale)
    }

    @Test func keyUsesVisibleRoundedValuesAndEveryRenderingInput() {
        let baseline = key(reading())
        #expect(baseline == key(reading(temperature: 72.2, load: 0.502)))
        #expect(baseline == key(reading(pressure: .fair, trend: .steady)))
        let changed = [reading(item: .temperature), reading(item: .load), reading(unit: .fahrenheit),
                       reading(temperature: 73), reading(load: 0.52), reading(pressure: .serious),
                       reading(trend: .rising), reading(trend: .falling), reading(stale: true),
                       reading(temperature: nil), reading(load: nil)]
        for value in changed { #expect(baseline != key(value)) }
        #expect(key(reading(temperature: 45, pressure: .serious)) != key(reading(temperature: 45, pressure: .critical)))
        #expect(baseline != key(reading(), scheme: .light))
        #expect(baseline != key(reading(), scale: 1))
        #expect(baseline != key(reading(), textScale: 1))
    }

    @Test func nativeItemReusesImagesButKeepsAccessibilityAndFreshnessCurrent() async throws {
        let suite = "Thermals.MenuCacheTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(MenuBarItem.temperature.rawValue, forKey: "menuBarItem")
        defaults.set(TemperatureUnit.celsius.rawValue, forKey: "temperatureUnit")
        let now = Date.now
        let source = MenuSamples(sample: SensorSample(date: now, sensors: [SensorReading(id: 1, name: "PMU tdie1", celsius: 42.1)]))
        let monitor = Monitor(sensors: [], cpuLoad: nil, thermalState: .nominal, history: [], collect: { await source.read() })
        await monitor.refresh()
        let controller = StatusItemController(monitor: monitor, updater: Updater(previewing: "0.4.4"), registersShortcut: false, defaults: defaults)
        defer { controller.stop() }
        let button = try #require(controller.item.button)
        controller.updateLabel(at: now)
        let first = try #require(button.image)
        for _ in 0..<1_000 { controller.updateLabel(at: now) }
        #expect(button.image === first)
        #expect(button.image?.isTemplate == false)
        await source.set(SensorSample(date: now.addingTimeInterval(1), sensors: [SensorReading(id: 1, name: "PMU tdie1", celsius: 42.2)], thermalState: .fair))
        await monitor.refresh()
        controller.updateLabel(at: now.addingTimeInterval(1))
        #expect(button.image === first)
        #expect(button.accessibilityLabel()?.contains("fair") == true)
        #expect(button.toolTip == button.accessibilityLabel())

        defaults.set(TemperatureUnit.fahrenheit.rawValue, forKey: "temperatureUnit")
        controller.updateLabel(at: now.addingTimeInterval(1))
        let fahrenheit = try #require(button.image)
        #expect(fahrenheit !== first)
        #expect(button.accessibilityLabel()?.contains("108°") == true)
        controller.updateLabel(at: now.addingTimeInterval(60))
        let stale = try #require(button.image)
        #expect(stale !== fahrenheit)
        #expect(button.accessibilityLabel()?.contains("stale") == true)
        controller.updateLabel(at: now.addingTimeInterval(61))
        #expect(button.image === stale)

        await source.set(SensorSample(date: now.addingTimeInterval(62)))
        await monitor.refresh()
        controller.updateLabel(at: now.addingTimeInterval(62))
        #expect(button.image !== stale)
        #expect(button.accessibilityLabel()?.contains("unavailable") == true)
        #expect(button.accessibilityLabel()?.contains("stale") == false)
    }
}

private actor MenuSamples {
    var sample: SensorSample
    init(sample: SensorSample) { self.sample = sample }
    func read() -> SensorSample { sample }
    func set(_ sample: SensorSample) { self.sample = sample }
}
