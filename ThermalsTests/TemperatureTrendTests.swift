import AppKit
import Foundation
import SwiftUI
import Testing
@testable import Thermals

struct TemperatureTrendTests {
    private let now = Date(timeIntervalSinceReferenceDate: 1_000)

    /// Readings every `step` seconds over the last `span` seconds, from `start` changing by `perMinute` °C per minute.
    private func readings(start: Double, perMinute: Double, span: TimeInterval = 60, step: TimeInterval = 6, jitter: [Double] = [0]) -> [TimedValue] {
        stride(from: -span, through: 0, by: step).enumerated().map { index, offset in
            TimedValue(date: now.addingTimeInterval(offset), value: start + perMinute * (offset + span) / 60 + jitter[index % jitter.count])
        }
    }

    @Test func climbingAtTheDeadZoneOrFasterIsRising() {
        #expect(TemperatureTrend(readings(start: 60, perMinute: 5), now: now) == .rising)
        #expect(TemperatureTrend(readings(start: 50, perMinute: 20), now: now) == .rising)
    }

    @Test func coolingFastIsFalling() {
        #expect(TemperatureTrend(readings(start: 85, perMinute: -12), now: now) == .falling)
    }

    @Test func slowDriftAndJitterAreSteady() {
        #expect(TemperatureTrend(readings(start: 55, perMinute: 3.5), now: now) == .steady)
        #expect(TemperatureTrend(readings(start: 50, perMinute: 0, jitter: [0, 2, -1, 1.5, -2]), now: now) == .steady)
    }

    @Test func tooFewOrTooShortReadingsClaimNothing() {
        #expect(TemperatureTrend(readings(start: 50, perMinute: 30, span: 12), now: now) == nil)
        #expect(TemperatureTrend(Array(readings(start: 50, perMinute: 30).suffix(2)), now: now) == nil)
        #expect(TemperatureTrend([], now: now) == nil)
    }

    @Test func readingOrderDoesNotMatter() {
        #expect(TemperatureTrend(readings(start: 50, perMinute: 20).reversed(), now: now) == .rising)
    }

    @Test func onlyTheLastMinuteCounts() {
        // A fast climb two minutes ago, flat since.
        let old = readings(start: 40, perMinute: 30).map { TimedValue(date: $0.date.addingTimeInterval(-120), value: $0.value) }
        #expect(TemperatureTrend(old + readings(start: 70, perMinute: 0), now: now) == .steady)
    }
}

@MainActor
struct MenuBarTrendTests {
    @Test func arrowFollowsTheTemperatureInItsColor() {
        let view = MenuBarReading(item: .both, unit: .celsius, temperature: 72, load: 0.5, thermalState: .nominal, trend: .rising)
        #expect(view.parts.map(\.0) == ["72°", "↑", "50%"])
        #expect(view.parts[1].1 == view.parts[0].1)
        #expect(view.accessibilityText.contains("CPU 72°, rising"))
    }

    @Test func steadyLoadOnlyAndMissingTemperatureShowNoArrow() {
        #expect(MenuBarReading(item: .temperature, unit: .celsius, temperature: 72, load: nil, thermalState: .nominal, trend: .steady).parts.map(\.0) == ["72°"])
        #expect(MenuBarReading(item: .load, unit: .celsius, temperature: 72, load: 0.5, thermalState: .nominal, trend: .falling).parts.map(\.0) == ["50%"])
        #expect(MenuBarReading(item: .temperature, unit: .celsius, temperature: nil, load: nil, thermalState: .serious, trend: .rising).parts.map(\.0) == ["!", "--°"])
    }

    @Test(.enabled(if: PopoverSnapshotTests.directory != nil))
    func renderMenuBarTrends() throws {
        let rows = VStack(alignment: .leading, spacing: 6) {
            ForEach([ColorScheme.dark, .light], id: \.self) { scheme in
                HStack(spacing: 18) {
                    MenuBarReading(item: .temperature, unit: .celsius, temperature: 58, load: nil, thermalState: .nominal, trend: .rising)
                    MenuBarReading(item: .temperature, unit: .fahrenheit, temperature: 88, load: nil, thermalState: .nominal, trend: .falling)
                    MenuBarReading(item: .both, unit: .celsius, temperature: 93, load: 0.96, thermalState: .serious, trend: .rising)
                    MenuBarReading(item: .temperature, unit: .celsius, temperature: 47, load: nil, thermalState: .nominal, trend: .steady)
                }
                .padding(8)
                .background(scheme == .dark ? Color(white: 0.16) : Color(white: 0.92))
                .environment(\.colorScheme, scheme)
            }
        }
        let renderer = ImageRenderer(content: rows)
        renderer.scale = 3
        let image = try #require(renderer.cgImage)
        let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try png.write(to: URL(fileURLWithPath: PopoverSnapshotTests.directory!).appendingPathComponent("menubar-trend.png"))
    }
}
