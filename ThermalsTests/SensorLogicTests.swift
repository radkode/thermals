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
