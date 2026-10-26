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
        #expect(HeatLevel.menuBar(celsius: 45, thermalState: .nominal)?.band == .cool)
    }

    @Test func menuBarRisesWithThermalPressure() {
        #expect(HeatLevel.menuBar(celsius: 45, thermalState: .serious)?.band == .hot)
        #expect(HeatLevel.menuBar(celsius: 80, thermalState: .critical)?.band == .burn)
        #expect(HeatLevel.menuBar(celsius: 95, thermalState: .serious)?.band == .burn)
    }

    @Test func menuBarHasNoBandWithoutReadingOrPressure() {
        #expect(HeatLevel.menuBar(celsius: nil, thermalState: .nominal) == nil)
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
    @Test func newestReadingsFillRightmostColumns() {
        let peaks = LampMeter.columnPeaks([40, 55, 50, 61])
        #expect(peaks.count == LampMeter.columns)
        #expect(peaks.suffix(2) == [40, 61])
        #expect(peaks.dropLast(2).allSatisfy { $0 == nil })
    }

    @Test func fullHistoryUsesPeakPerColumn() {
        let values = (0..<Monitor.historyLength).map { Double($0) }
        let peaks = LampMeter.columnPeaks(values)
        #expect(peaks.first == 2)
        #expect(peaks.last == Double(Monitor.historyLength - 1))
    }
}

struct LoadBandTests {
    @Test(arguments: [(24.9, HeatBand.cool), (25, .warm), (59.9, .warm), (60, .hot), (84.9, .hot), (85, .burn), (240, .burn)])
    func bandBoundaries(percent: Double, expected: HeatBand) {
        #expect(HeatBand(loadPercent: percent) == expected)
    }
}

struct CoreLayoutTests {
    @Test func namesPerformanceCoresFirstThenEfficiencyByLogicalID() {
        let cores = [
            CoreInfo(logicalID: 0, cluster: .efficiency),
            CoreInfo(logicalID: 1, cluster: .efficiency),
            CoreInfo(logicalID: 3, cluster: .performance),
            CoreInfo(logicalID: 2, cluster: .performance),
        ]
        let names = CoreLayout.names(for: cores)
        #expect(names.map(\.name) == ["P1", "P2", "E1", "E2"])
        #expect(names.map(\.logicalID) == [2, 3, 0, 1])
    }

    @Test func fallsBackToNumberedCoresWithoutClusterData() {
        let cores = [CoreInfo(logicalID: 1, cluster: nil), CoreInfo(logicalID: 0, cluster: .performance)]
        #expect(CoreLayout.names(for: cores).map(\.name) == ["CPU1", "CPU2"])
    }
}

struct ProcessSamplerTests {
    @Test func percentOfOneCoreSummedByName() {
        let previous: [pid_t: ProcessTimes] = [
            1: ProcessTimes(name: "Helper", cpuNanoseconds: 1_000),
            2: ProcessTimes(name: "Helper", cpuNanoseconds: 5_000),
            3: ProcessTimes(name: "Xcode", cpuNanoseconds: 0),
        ]
        let current: [pid_t: ProcessTimes] = [
            1: ProcessTimes(name: "Helper", cpuNanoseconds: 1_000_000_000 + 1_000),
            2: ProcessTimes(name: "Helper", cpuNanoseconds: 500_000_000 + 5_000),
            3: ProcessTimes(name: "Xcode", cpuNanoseconds: 3_000_000_000),
            4: ProcessTimes(name: "New", cpuNanoseconds: 9_000_000_000),
        ]
        let percents = ProcessSampler.percents(previous: previous, current: current, elapsedNanoseconds: 2_000_000_000)
        #expect(percents == ["Helper": 75, "Xcode": 150])
    }

    @Test func reusedPidWithNewNameHasNoBaseline() {
        let previous: [pid_t: ProcessTimes] = [7: ProcessTimes(name: "old", cpuNanoseconds: 0)]
        let current: [pid_t: ProcessTimes] = [7: ProcessTimes(name: "new", cpuNanoseconds: 1_000_000_000)]
        #expect(ProcessSampler.percents(previous: previous, current: current, elapsedNanoseconds: 1_000_000_000).isEmpty)
    }

    @Test func smoothingHalvesTowardNewValueAndDropsQuietNames() {
        let result = ProcessSampler.smooth(previous: ["A": 100, "B": 0.06], current: ["A": 50, "C": 20])
        #expect(result == ["A": 75, "C": 20])
    }

    @Test func rankedHighestFirstThenByName() {
        let ranked = ProcessSampler.ranked(["b": 10, "a": 10, "c": 30])
        #expect(ranked.map(\.name) == ["c", "a", "b"])
    }
}

struct ProcessGroupingTests {
    @Test func helpersGroupUnderOutermostApp() {
        let path = "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Versions/131/Helpers/Google Chrome Helper (Renderer).app/Contents/MacOS/Google Chrome Helper (Renderer)"
        #expect(ProcessSampler.groupName(path: path, processName: "Google Chrome Helper (Renderer)") == "Google Chrome")
    }

    @Test func processesOutsideAppsKeepTheirName() {
        #expect(ProcessSampler.groupName(path: "/usr/local/bin/node", processName: "node") == "node")
        #expect(ProcessSampler.groupName(path: nil, processName: "launchd") == "launchd")
    }

    @Test func percentsSumHelpersIntoTheirGroup() {
        let previous: [pid_t: ProcessTimes] = [
            1: ProcessTimes(name: "Chrome Helper", cpuNanoseconds: 0, group: "Google Chrome"),
            2: ProcessTimes(name: "Google Chrome", cpuNanoseconds: 0, group: "Google Chrome"),
        ]
        let current: [pid_t: ProcessTimes] = [
            1: ProcessTimes(name: "Chrome Helper", cpuNanoseconds: 500_000_000, group: "Google Chrome"),
            2: ProcessTimes(name: "Google Chrome", cpuNanoseconds: 250_000_000, group: "Google Chrome"),
        ]
        #expect(ProcessSampler.percents(previous: previous, current: current, elapsedNanoseconds: 1_000_000_000) == ["Google Chrome": 75])
    }
}

struct HiddenLoadTests {
    @Test func hiddenLoadIsTotalInCorePercentMinusVisible() {
        #expect(Monitor.hiddenLoad(totalFraction: 0.5, cores: 4, visibleTotal: 120) == 80)
    }

    @Test func hiddenLoadNeverNegative() {
        #expect(Monitor.hiddenLoad(totalFraction: 0.1, cores: 4, visibleTotal: 120) == 0)
    }
}

struct HeatLevelTests {
    @Test func bandEdgesLandOnFixedPositions() {
        #expect(HeatLevel(celsius: 50).position == HeatLevel.warmStart)
        #expect(HeatLevel(celsius: 75).position == HeatLevel.hotStart)
        #expect(HeatLevel(celsius: 90).position == HeatLevel.burnStart)
        #expect(HeatLevel(loadPercent: 25).position == HeatLevel.warmStart)
        #expect(HeatLevel(loadPercent: 60).position == HeatLevel.hotStart)
        #expect(HeatLevel(loadPercent: 85).position == HeatLevel.burnStart)
    }

    @Test func clampsOutsideTheScale() {
        #expect(HeatLevel(celsius: 20).position == 0)
        #expect(HeatLevel(celsius: 120).position == 1)
        #expect(HeatLevel(loadPercent: 400).position == 1)
    }

    @Test func risesSmoothlyWithinABand() {
        let positions = stride(from: 30.0, through: 105, by: 1).map { HeatLevel(celsius: $0).position }
        #expect(zip(positions, positions.dropFirst()).allSatisfy { $0 < $1 })
        #expect(HeatLevel(celsius: 52).position < HeatLevel(celsius: 73).position)
        #expect(HeatLevel(celsius: 52).band == HeatLevel(celsius: 73).band)
    }

    @Test func gradientStopsSitOnBandEdgesInBothSchemes() {
        for stops in [Board.darkHeatStops, Board.lightHeatStops] {
            let positions = stops.map(\.position)
            #expect(positions == positions.sorted())
            #expect(positions.first == 0 && positions.last == 1)
            #expect([HeatLevel.warmStart, HeatLevel.hotStart, HeatLevel.burnStart].allSatisfy(positions.contains))
        }
    }
}
