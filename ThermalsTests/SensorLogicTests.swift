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
        #expect(TemperatureSensors.byName(input).map(\.label) == ["CPU DIE 1", "CPU DIE 2", "CPU DIE 10", "SSD"])
    }
}

struct SensorLabelTests {
    static let m3Pro = ["gas gauge battery", "NAND CH0 temp"] + (1...8).map { "PMU tdev\($0)" } + (1...10).map { "PMU tdie\($0)" }

    @Test func everyM3ProSensorGetsALabelThatFitsTheBoard() {
        for name in Self.m3Pro {
            let label = SensorLabels.label(for: name)
            #expect(label != name, "\(name) has no label")
            #expect(label.count <= SensorBoard.nameCells, "\(label) overflows")
        }
    }

    @Test(arguments: [
        ("PMU tdie6", "CPU DIE 6"), ("PMU tdev3", "PMU DEV 3"), ("gas gauge battery", "BATTERY"),
        ("NAND CH0 temp", "SSD"), ("NAND CH1 temp", "SSD CH 1"), ("SOC MTR Temp Sensor0", "SOC 0"),
    ])
    func knownNamesMapToLabels(name: String, label: String) {
        #expect(SensorLabels.label(for: name) == label)
    }

    @Test(arguments: ["PMU tdie", "PMU tdieX", "Mystery Sensor 4", "PMU tcal"])
    func unknownNamesStayRaw(name: String) {
        #expect(SensorLabels.label(for: name) == name)
    }
}

@MainActor
struct LampMeterTests {
    private let newest = Date(timeIntervalSince1970: 1_000)

    private func reading(_ secondsAgo: Double, _ value: Double) -> TimedValue {
        TimedValue(date: newest.addingTimeInterval(-secondsAgo), value: value)
    }

    @Test func columnsAreTimeSlicesEndingAtTheNewestReading() {
        let peaks = LampMeter.columnPeaks([reading(7, 50), reading(2, 61), reading(0, 55)])
        #expect(peaks.count == LampMeter.columns)
        #expect(peaks.last == 61)
        #expect(peaks[LampMeter.columns - 2] == 50)
        #expect(peaks.dropLast(2).allSatisfy { $0 == nil })
    }

    @Test func timerJitterAtTheSliceRateLeavesNoGaps() {
        let peaks = LampMeter.columnPeaks([reading(17.8, 1), reading(12.0, 2), reading(5.9, 3), reading(0, 4)])
        #expect(Array(peaks.suffix(4)) == [1, 2, 3, 4])
    }

    @Test func slowerRatesHoldTheLastValueAcrossEmptySlices() {
        let readings = stride(from: 60.0, through: 0, by: -10).enumerated().map { reading($0.element, Double($0.offset)) }
        let peaks = LampMeter.columnPeaks(readings)
        let firstFilled = peaks.firstIndex { $0 != nil }!
        #expect(peaks[firstFilled...].allSatisfy { $0 != nil })
        #expect(peaks.last == 6)
    }

    @Test func readingsOlderThanTheWindowAreDropped() {
        let peaks = LampMeter.columnPeaks([reading(Monitor.historyWindow + 1, 99), reading(0, 40)])
        #expect(peaks.compactMap { $0 } == [40])
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

    @Test func pathNamesBeatTruncatedProcessNames() {
        let path = "/System/Library/Frameworks/Virtualization.framework/Versions/A/XPCServices/com.apple.Virtualization.VirtualMachine.xpc/Contents/MacOS/com.apple.Virtualization.VirtualMachine"
        #expect(ProcessSampler.groupName(path: path, processName: "com.apple.Virtualization.Virtua") == "VirtualMachine")
    }

    @Test func versionNamedBinariesTakeTheirToolFolder() {
        #expect(ProcessSampler.groupName(path: "/Users/me/.local/share/claude/versions/2.1.310", processName: "2.1.310") == "claude")
        #expect(ProcessSampler.groupName(path: "/opt/tool/v20.11.1/bin/node", processName: "node") == "node")
        #expect(ProcessSampler.groupName(path: "/opt/zed/V1.2/1.2.3-beta.1", processName: "1.2.3-beta.1") == "zed")
    }

    @Test func folderSearchStopsTwoFoldersUp() {
        #expect(ProcessSampler.groupName(path: "/opt/tool/versions/current/1.2", processName: "1.2") == "1.2")
    }

    @Test func plainDottedNamesStayWhole() {
        #expect(ProcessSampler.groupName(path: "/usr/local/bin/swift-frontend", processName: "swift-frontend") == "swift-frontend")
        #expect(ProcessSampler.groupName(path: "/usr/bin/python3.12", processName: "python3.12") == "python3.12")
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

struct MeterScaleTests {
    @Test func fitsRowsToTheWindowRange() {
        let floors = MeterScale.temperature.floors(for: [40, 52, 60])
        #expect(floors.count == 8)
        #expect(floors.first == 40)
        #expect(abs(floors.last! - 60) < 1e-9)
    }

    @Test func narrowRangeWidensToMinimumSpanAroundTheMiddle() {
        let floors = MeterScale.temperature.floors(for: [45, 47])
        #expect(floors.first == 41)
        #expect(abs(floors.last! - 51) < 1e-9)
    }

    @Test func staysInsideBounds() {
        let floors = MeterScale.load.floors(for: [0, 5])
        #expect(floors.first == 0)
        #expect(abs(floors.last! - 20) < 1e-9)
    }
}

@MainActor
struct SensorBoardFillTests {
    @Test func rowsThatFitMatchesRowHeight() {
        #expect(SensorBoard.rowsThatFit(height: SensorBoard.height(rows: 8)) == 8)
        #expect(SensorBoard.rowsThatFit(height: SensorBoard.height(rows: 8) - 1) == 7)
    }
}

struct MemoryStatsTests {
    @Test func breakdownCountsPurgeableAsCache() {
        let pages = VMPages(anonymous: 600, purgeable: 100, external: 200, wired: 150, compressed: 50, free: 20)
        let reading = MemoryReading(pages: pages, pageSize: 16_384, total: 1_000 * 16_384, swapUsed: 0, pressure: .normal)
        #expect(reading.app == 500 * 16_384)
        #expect(reading.cached == 300 * 16_384)
        #expect(reading.used == 700 * 16_384)
        #expect(reading.free == 20 * 16_384)
        #expect(reading.usedPercent == 70)
    }

    @Test func anonymousPagesBelowPurgeableCountNoAppMemory() {
        let pages = VMPages(anonymous: 5, purgeable: 9, external: 0, wired: 0, compressed: 0, free: 0)
        #expect(MemoryReading(pages: pages, pageSize: 1, total: 100, swapUsed: 0, pressure: nil).app == 0)
    }

    @Test(arguments: [(Int32(1), MemoryPressure.normal), (2, .warn), (4, .critical)])
    func pressureFromKernelLevel(level: Int32, expected: MemoryPressure) {
        #expect(MemoryPressure(kernelLevel: level) == expected)
    }

    @Test func unknownKernelLevelIsNil() {
        #expect(MemoryPressure(kernelLevel: 0) == nil)
    }

    @Test func rankedLargestFirstThenByName() {
        #expect(MemoryStats.ranked(["b": 10, "a": 10, "c": 30]).map(\.name) == ["c", "a", "b"])
    }

    @Test func gigabytesUseOneDecimalBelowAHundred() {
        #expect(Format.gigabytes(1_073_741_824 * 9 + 858_993_459) == "9.8")
        #expect(Format.gigabytes(0) == "0.0")
        #expect(Format.gigabytes(1_073_741_824 * 128) == "128")
    }
}

struct MemoryBandTests {
    @Test(arguments: [(59.9, HeatBand.cool), (60, .warm), (79.9, .warm), (80, .hot), (89.9, .hot), (90, .burn)])
    func usedBandBoundaries(percent: Double, expected: HeatBand) {
        #expect(HeatBand(memoryPercent: percent) == expected)
    }

    @Test(arguments: [(9.9, HeatBand.cool), (10, .warm), (25, .hot), (40, .burn)])
    func appBandBoundaries(percent: Double, expected: HeatBand) {
        #expect(HeatBand(appMemoryPercent: percent) == expected)
    }

    @Test func pressureRaisesTheUsedLevel() {
        #expect(HeatLevel.memory(usedPercent: 40, pressure: .normal).band == .cool)
        #expect(HeatLevel.memory(usedPercent: 40, pressure: .warn).band == .hot)
        #expect(HeatLevel.memory(usedPercent: 40, pressure: .critical).band == .burn)
        #expect(HeatLevel.memory(usedPercent: 95, pressure: .warn).band == .burn)
        #expect(HeatLevel.memory(usedPercent: 70, pressure: nil).band == .warm)
    }
}

@MainActor
struct BreakdownLensTests {
    @Test func lensesNeverExceedTheWhole() {
        let lit = BreakdownBoard.lenses(shares: [32.5, 11.25, 8.125, 33.75, 14.375])
        #expect(lit.reduce(0, +) == 8)
        #expect(lit == [2, 1, 1, 3, 1])
    }

    @Test func partsBelowTheWholeLightOnlyTheirShare() {
        #expect(BreakdownBoard.lenses(shares: [25, 25, 0.5]) == [2, 2, 0])
        #expect(BreakdownBoard.lenses(shares: []) == [])
    }
}
