import Foundation
import Testing
@testable import Thermals

struct CPULoadTests {
    @Test func usageIsBusyShareOfElapsedTicks() {
        let previous = CPUTicks(user: 100, system: 50, idle: 850, nice: 0)
        let current = CPUTicks(user: 200, system: 100, idle: 900, nice: 0)
        #expect(CPULoad.usage(from: previous, to: current) == 0.75)
    }

    @Test func usageIsNilWhenNoTicksElapsed() {
        let ticks = CPUTicks(user: 100, system: 50, idle: 850, nice: 0)
        #expect(CPULoad.usage(from: ticks, to: ticks) == nil)
    }
}

struct CPUTemperatureTests {
    private func readings(_ pairs: [(String, Double)]) -> [SensorReading] {
        pairs.enumerated().map { SensorReading(id: $0.offset, name: $0.element.0, celsius: $0.element.1) }
    }

    @Test func picksHottestDieSensor() {
        let input = readings([("PMU tdie1", 50), ("PMU tdie2", 62.5), ("PMU tcal", 51.8), ("NAND CH0 temp", 70), ("gas gauge battery", 30)])
        #expect(TemperatureSensors.cpuTemperature(from: input) == 62.5)
    }

    @Test func fallsBackToPMUSensorsExcludingCalibration() {
        let input = readings([("PMU tdev1", 45), ("PMU tcal", 51.8), ("NAND CH0 temp", 40)])
        #expect(TemperatureSensors.cpuTemperature(from: input) == 45)
    }

    @Test func returnsNilWithoutCPUSensors() {
        let input = readings([("NAND CH0 temp", 40), ("gas gauge battery", 30)])
        #expect(TemperatureSensors.cpuTemperature(from: input) == nil)
    }

    @Test func usableDropsCalibrationAndImplausibleReadings() {
        let input = readings([("PMU tcal", 51.8), ("PMU tdie1", 46), ("NAND CH0 temp", 0), ("gas gauge battery", 31)])
        #expect(TemperatureSensors.usable(input).map(\.name) == ["PMU tdie1", "gas gauge battery"])
    }

    @Test func ignoresImplausibleReadings() {
        let input = readings([("PMU tdie1", 0), ("PMU tdie2", 200), ("PMU tdie3", 48)])
        #expect(TemperatureSensors.cpuTemperature(from: input) == 48)
    }
}

struct HeatBandTests {
    @Test(arguments: [(49.9, HeatBand.cool), (50, .warm), (74.9, .warm), (75, .hot), (89.9, .hot), (90, .burn)])
    func bandBoundaries(celsius: Double, expected: HeatBand) {
        #expect(HeatBand(celsius: celsius) == expected)
    }

    @Test func menuBarStaysCalmWhenCoolAndNominal() {
        #expect(HeatBand.menuBar(celsius: 45, thermalState: .nominal) == .cool)
    }

    @Test func menuBarRisesWithThermalPressure() {
        #expect(HeatBand.menuBar(celsius: 45, thermalState: .serious) == .hot)
        #expect(HeatBand.menuBar(celsius: 80, thermalState: .critical) == .burn)
        #expect(HeatBand.menuBar(celsius: 95, thermalState: .serious) == .burn)
    }

    @Test func menuBarHasNoBandWithoutReadingOrPressure() {
        #expect(HeatBand.menuBar(celsius: nil, thermalState: .nominal) == nil)
    }
}

struct ByNameTests {
    @Test func keepsHottestReadingPerName() {
        let input = [
            SensorReading(id: 0, name: "PMU tdie2", celsius: 46.1),
            SensorReading(id: 1, name: "PMU tdie2", celsius: 46.3),
        ]
        #expect(TemperatureSensors.byName(input).map(\.id) == [1])
    }

    @Test func ordersByNaturalNameRegardlessOfTemperature() {
        let input = [
            SensorReading(id: 0, name: "PMU tdie10", celsius: 40),
            SensorReading(id: 1, name: "PMU tdie2", celsius: 90),
            SensorReading(id: 2, name: "NAND CH0 temp", celsius: 60),
            SensorReading(id: 3, name: "PMU tdie1", celsius: 70),
        ]
        #expect(TemperatureSensors.byName(input).map(\.name) == ["NAND CH0 temp", "PMU tdie1", "PMU tdie2", "PMU tdie10"])
    }
}

@MainActor
struct LampMeterTests {
    private func samples(_ values: [Double]) -> [TemperatureSample] {
        values.enumerated().map { TemperatureSample(date: Date(timeIntervalSince1970: Double($0.offset)), celsius: $0.element) }
    }

    @Test func newestReadingsFillRightmostColumns() {
        let peaks = LampMeter.columnPeaks(samples([40, 55, 50, 61]))
        #expect(peaks.count == LampMeter.columns)
        #expect(peaks.suffix(2) == [40, 61])
        #expect(peaks.dropLast(2).allSatisfy { $0 == nil })
    }

    @Test func fullHistoryUsesPeakPerColumn() {
        let values = (0..<Monitor.historyLength).map { Double($0) }
        let peaks = LampMeter.columnPeaks(samples(values))
        #expect(peaks.first == 2)
        #expect(peaks.last == Double(Monitor.historyLength - 1))
    }
}
