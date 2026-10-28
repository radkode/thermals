import Foundation
import ServiceManagement
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

    @Test func columnsAreTimeSlicesEndingAtNow() {
        let peaks = LampMeter.columnPeaks([reading(7, 50), reading(2, 61), reading(0, 55)], now: newest)
        #expect(peaks.count == LampMeter.columns)
        #expect(peaks.last == 61)
        #expect(peaks[LampMeter.columns - 2] == 50)
        #expect(peaks.dropLast(2).allSatisfy { $0 == nil })
    }

    @Test func timerJitterAtTheSliceRateLeavesNoGaps() {
        let peaks = LampMeter.columnPeaks([reading(17.8, 1), reading(12.0, 2), reading(5.9, 3), reading(0, 4)], now: newest)
        #expect(Array(peaks.suffix(4)) == [1, 2, 3, 4])
    }

    @Test func slowerRatesHoldTheLastValueAcrossEmptySlices() {
        let readings = stride(from: 60.0, through: 0, by: -10).enumerated().map { reading($0.element, Double($0.offset)) }
        let peaks = LampMeter.columnPeaks(readings, now: newest)
        let firstFilled = peaks.firstIndex { $0 != nil }!
        #expect(peaks[firstFilled...].allSatisfy { $0 != nil })
        #expect(peaks.last == 6)
    }

    @Test func readingsOlderThanTheWindowAreDropped() {
        let peaks = LampMeter.columnPeaks([reading(Monitor.historyWindow + 1, 99), reading(0, 40)], now: newest)
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
    @Test func percentageBinsHaveStableCapacity() {
        let scale = MeterScale.percentage
        #expect(scale.bounds == 0...100)
        for (value, count) in [(0.0, 0), (0.01, 1), (12.5, 1), (12.5001, 2), (50, 4), (100, 8), (120, 8)] {
            #expect((0..<MeterScale.rows).filter { scale.isLit(value, row: $0) }.count == count)
        }
    }

    @Test func percentageColorsUseOneLinearRamp() {
        let positions = (0..<MeterScale.rows).map { MeterScale.percentage.level(row: $0).position }
        #expect(positions == (1...8).map { Double($0) / 8 })
        #expect(positions.last == 1)
    }

    @Test func temperatureHasFixedPhysicalBounds() {
        let scale = MeterScale.temperature
        #expect(scale.bounds == 20...110)
        for (value, count) in [(20.0, 0), (20.01, 1), (65, 4), (110, 8)] {
            #expect((0..<MeterScale.rows).filter { scale.isLit(value, row: $0) }.count == count)
        }
        #expect(scale.level(row: 7).position == 1)
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

    @Test func wattsRoundToWholeWatts() {
        #expect(Format.watts(19.84) == "20W")
        #expect(Format.watts(0.4) == "0W")
        #expect(Format.watts(142.5) == "143W")
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

    @Test func onlyPressureUsesMemoryWarningColors() {
        #expect(HeatLevel.memory(usedPercent: 40, pressure: .normal).band == .cool)
        #expect(HeatLevel.memory(usedPercent: 40, pressure: .warn).band == .hot)
        #expect(HeatLevel.memory(usedPercent: 40, pressure: .critical).band == .burn)
        #expect(HeatLevel.memory(usedPercent: 95, pressure: .warn).band == .hot)
        #expect(HeatLevel.memory(usedPercent: 100, pressure: .normal).band < .hot)
        #expect(HeatLevel.memory(usedPercent: 100, pressure: nil).band < .hot)
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

struct PSParsingTests {
    @Test(arguments: [("0:01.50", 1.5), ("745:38.02", 44_738.02), ("1:02:03.00", 3_723.0), ("2-01:00:00.00", 176_400.0)])
    func cpuTimeFormats(time: String, seconds: Double) {
        #expect(abs(ProcessSampler.cpuSeconds(time)! - seconds) < 1e-6)
    }

    @Test(arguments: ["", "abc", "1:2:3:4", "x-1:00.00", "0:nan", "0:inf", "01::02", "-01:02"])
    func malformedCPUTimeIsNil(time: String) {
        #expect(ProcessSampler.cpuSeconds(time) == nil)
    }

    @Test func linesKeepPathsWithSpacesAndGroupByApp() {
        let output = """
              1   196:13.72 /sbin/launchd
            404   745:38.02 /System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer
            812     0:02.50 /Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Helpers/Google Chrome Helper (Renderer).app/Contents/MacOS/Google Chrome Helper (Renderer)
            900     garbage /usr/bin/true
            """
        let times = ProcessSampler.parse(output)
        #expect(times.keys.sorted() == [1, 404, 812])
        #expect(times[404]?.group == "WindowServer")
        #expect(times[812]?.group == "Google Chrome")
        #expect(times[812]?.name == "Google Chrome Helper (Renderer)")
        #expect(times[812]?.cpuNanoseconds == 2_500_000_000)
    }

    @Test func samplerReportsNothingUntilItHasABaseline() {
        let sampler = ProcessSampler()
        let first = ProcessSnapshot(times: [7: ProcessTimes(name: "a", cpuNanoseconds: 0, group: "A")], uptimeNanoseconds: 1_000_000_000)
        let second = ProcessSnapshot(times: [7: ProcessTimes(name: "a", cpuNanoseconds: 500_000_000, group: "A")], uptimeNanoseconds: 2_000_000_000)
        #expect(sampler.sample(first) == nil)
        #expect(sampler.sample(second)?.ranked == [ProcessLoad(name: "A", percent: 50)])
    }
}

struct LaunchAtLoginTests {
    @Test func onlyAnApprovedItemReadsAsOn() {
        #expect(LaunchAtLogin(status: .enabled) == .on)
        #expect(LaunchAtLogin(status: .requiresApproval) == .off)
        #expect(LaunchAtLogin(status: .notRegistered) == .off)
        #expect(LaunchAtLogin(status: .notFound) == .off)
    }
}

struct UpdateNoticeTests {
    @Test func eachVersionIsNotifiedOnce() {
        #expect(UpdateNotice.shouldNotify(version: "0.3.0", lastNotified: nil))
        #expect(!UpdateNotice.shouldNotify(version: "0.3.0", lastNotified: "0.3.0"))
        #expect(UpdateNotice.shouldNotify(version: "0.3.1", lastNotified: "0.3.0"))
    }
}

struct TemperatureUnitTests {
    @Test(arguments: [(0.0, 32.0), (100, 212), (37, 98.6), (-40, -40)])
    func fahrenheitConversion(celsius: Double, fahrenheit: Double) {
        #expect(abs(TemperatureUnit.fahrenheit.value(celsius) - fahrenheit) < 1e-9)
        #expect(TemperatureUnit.celsius.value(celsius) == celsius)
    }

    @Test func degreesFormatInTheChosenUnit() {
        #expect(Format.degrees(93.4) == "93°")
        #expect(Format.degrees(93.4, unit: .fahrenheit) == "200°")
    }

    @MainActor @Test(arguments: TemperatureUnit.allCases)
    func plausibleReadingsFitTheirCells(unit: TemperatureUnit) {
        for celsius in [TemperatureSensors.plausibleRange.lowerBound, 99.5, TemperatureSensors.plausibleRange.upperBound] {
            #expect("\(Int(unit.value(celsius).rounded()))".count <= SensorBoard.tempCells)
            #expect(Format.degrees(celsius, unit: unit).count <= 4)
        }
    }
}

struct SMCTests {
    @Test func parameterBlockMatchesTheCStruct() {
        #expect(MemoryLayout<SMCParams>.size == 80)
        #expect(MemoryLayout<SMCParams>.offset(of: \.keyInfo) == 28)
        #expect(MemoryLayout<SMCParams>.offset(of: \.result) == 40)
        #expect(MemoryLayout<SMCParams>.offset(of: \.data32) == 44)
        #expect(MemoryLayout<SMCParams>.offset(of: \.bytes) == 48)
    }

    @Test func fourCharCodesAreBigEndianASCII() {
        #expect(SMC.fourCharCode("FNum") == 0x464E_756D)
        #expect(SMC.fourCharCode("FNu") == nil)
    }

    @Test func decodesFanValueTypes() {
        #expect(SMC.decode([0x00, 0x70, 0xA9, 0x44], type: SMC.float) == 1355.5)
        #expect(SMC.decode([0x15, 0x18], type: SMC.fixedPoint) == 1350)
        #expect(SMC.decode([2], type: SMC.uint8) == 2)
        #expect(SMC.decode([0x05, 0x46], type: SMC.uint16) == 1350)
    }

    @Test func malformedOrUnknownValuesAreNil() {
        #expect(SMC.decode([0x00, 0x70], type: SMC.float) == nil)
        #expect(SMC.decode([0x00, 0x00, 0xC0, 0x7F], type: SMC.float) == nil)
        #expect(SMC.decode([1, 2], type: SMC.fourCharCode("si16")!) == nil)
    }

    @Test func implausibleCountsAndSpeedsAreUnavailable() {
        #expect(SMC.fanCount(2) == 2)
        #expect(SMC.fanCount(0) == 0)
        #expect(SMC.fanCount(9) == nil)
        #expect(SMC.fanCount(1.5) == nil)
        #expect(SMC.fanCount(1e30) == nil)
        #expect(SMC.plausibleRPM(1355.5) == 1355.5)
        #expect(SMC.plausibleRPM(-1) == nil)
        #expect(SMC.plausibleRPM(3e38) == nil)
    }

    @Test func systemPowerIsUnavailableWhenNotMeasuring() {
        #expect(SMC.plausibleWatts(19.84) == 19.84)
        #expect(SMC.plausibleWatts(0) == nil)
        #expect(SMC.plausibleWatts(-2) == nil)
        #expect(SMC.plausibleWatts(500) == nil)
        #expect(SMC.plausibleWatts(3e38) == nil)
    }

    @Test func fanFractionIsShareOfItsRange() {
        #expect(FanReading(id: 1, rpm: 3350, minimum: 1350, maximum: 5350).fraction == 0.5)
        #expect(FanReading(id: 1, rpm: 0, minimum: 1350, maximum: 5350).fraction == 0)
        #expect(FanReading(id: 1, rpm: 6000, minimum: 1350, maximum: 5350).fraction == 1)
        #expect(FanReading(id: 1, rpm: nil, minimum: 1350, maximum: 5350).fraction == nil)
        #expect(FanReading(id: 1, rpm: 1000, minimum: 0, maximum: 0).fraction == nil)
    }
}

@MainActor
struct ReadingFreshnessTests {
    private let now = Date(timeIntervalSince1970: 10_000)

    @Test func failedCPUReadDoesNotFabricateASample() {
        let monitor = Monitor(sensors: [], cpuLoad: nil, thermalState: .nominal, history: [])
        monitor.updateCPU(ticks: [.zero], at: now)
        monitor.updateCPU(ticks: [CPUTicks(user: 25, system: 0, idle: 75, nice: 0)], at: now.addingTimeInterval(1))
        #expect(monitor.cpuLoad == 0.25)
        #expect(monitor.loadHistory.count == 1)
        monitor.updateCPU(ticks: nil, at: now.addingTimeInterval(2))
        #expect(monitor.cpuLoad == nil)
        #expect(monitor.coreLoads.isEmpty)
        #expect(monitor.cpuState == .failed)
        #expect(monitor.loadHistory.count == 1)
        monitor.updateCPU(ticks: [CPUTicks(user: 50, system: 0, idle: 150, nice: 0)], at: now.addingTimeInterval(3))
        #expect(monitor.cpuLoad == nil)
        #expect(monitor.cpuState == .loading)
        #expect(monitor.loadHistory.count == 1)
    }

    @Test func unchangedCountersClearTheOldCPUValue() {
        let monitor = Monitor(sensors: [], cpuLoad: nil, thermalState: .nominal, history: [])
        let ticks = CPUTicks(user: 25, system: 0, idle: 75, nice: 0)
        monitor.updateCPU(ticks: [.zero], at: now)
        monitor.updateCPU(ticks: [ticks], at: now.addingTimeInterval(1))
        monitor.updateCPU(ticks: [ticks], at: now.addingTimeInterval(2))
        #expect(monitor.cpuLoad == nil)
        #expect(monitor.cpuState == .failed)
        #expect(monitor.loadHistory.count == 1)
    }

    @Test func historyExpiresEvenWhenItsSourceStops() {
        let reading = TimedValue(date: now, value: 70)
        let monitor = Monitor(sensors: [], cpuLoad: nil, thermalState: .nominal, history: [reading], loadHistory: [reading], memoryHistory: [reading])
        monitor.pruneHistory(at: now.addingTimeInterval(181))
        #expect(monitor.history.isEmpty)
        #expect(monitor.loadHistory.isEmpty)
        #expect(monitor.memoryHistory.isEmpty)
    }

    @Test func staleChartMovesAwayFromNowAndThenExpires() {
        let readings = [TimedValue(date: now, value: 70)]
        let delayed = LampMeter.columnPeaks(readings, now: now.addingTimeInterval(60))
        #expect(delayed.suffix(8).allSatisfy { $0 == nil })
        #expect(LampMeter.columnPeaks(readings, now: now.addingTimeInterval(181)).allSatisfy { $0 == nil })
    }

    @Test func sleepGapIsNotFilledWithAnInventedPlateau() {
        let readings = [TimedValue(date: now.addingTimeInterval(-120), value: 90), TimedValue(date: now, value: 40)]
        let columns = LampMeter.columnPeaks(readings, now: now)
        #expect(columns[15...25].allSatisfy { $0 == nil })
        #expect(columns.last == 40)
    }

    @Test func freshnessUsesTheSuccessfulSampleTime() {
        let state = ReadingState.available(now)
        #expect(!state.isStale(at: now.addingTimeInterval(10), interval: 10))
        #expect(state.isStale(at: now.addingTimeInterval(21), interval: 10))
        #expect(ReadingState.failed.sampledAt == nil)
    }
}

@MainActor
struct PressurePresentationTests {
    @Test(arguments: [MenuBarItem.temperature, .load, .both])
    func missingTemperatureStillWarns(item: MenuBarItem) {
        let view = MenuBarReading(item: item, unit: .celsius, temperature: nil, load: 0.1, thermalState: .critical)
        #expect(view.parts.first?.0 == "!")
        #expect(view.parts.first?.1.band == .burn)
        #expect(view.accessibilityText.contains("critical"))
        if item != .load { #expect(view.parts.contains { $0.0 == "--°" }) }
    }

    @Test func nominalMissingTemperatureDoesNotInventAValue() {
        let view = MenuBarReading(item: .temperature, unit: .celsius, temperature: nil, load: nil, thermalState: .nominal)
        #expect(view.parts.isEmpty)
        #expect(view.accessibilityText.contains("unavailable"))
    }

    @Test func lowTemperatureKeepsPressureColor() {
        let view = MenuBarReading(item: .temperature, unit: .celsius, temperature: 45, load: nil, thermalState: .serious)
        #expect(view.parts.last?.0 == "45°")
        #expect(view.parts.last?.1.band == .hot)
    }
}

@MainActor
struct UXPresentationTests {
    @Test func overflowNeverTurnsANumberIntoASmallerNumber() {
        #expect(FlapText.fitted("9999", cells: 4, numeric: true) == "9999")
        #expect(FlapText.fitted("10000", cells: 4, numeric: true) == "####")
        #expect(FlapText.fitted("10000", cells: 5, numeric: true) == "10000")
        #expect(FlapText.fitted("20000", cells: 5, numeric: true) == "20000")
        #expect(FlapText.fitted("A very long app name", cells: 8, numeric: false) == "A VERY …")
    }

    @Test func historyDirectionsAreDistinctEvenWithTheSameExtrema() {
        let now = Date.now
        let rising = [TimedValue(date: now.addingTimeInterval(-60), value: 40), TimedValue(date: now, value: 80)]
        let falling = [TimedValue(date: now.addingTimeInterval(-60), value: 80), TimedValue(date: now, value: 40)]
        #expect(LampMeter.trend(rising).hasPrefix("Rising"))
        #expect(LampMeter.trend(falling).hasPrefix("Falling"))
        #expect(LampMeter.trend([]).contains("Not enough"))
    }

    @Test func panelUsesAvailableScreenHeightWithClearance() {
        #expect(Board.panelHeight(available: 768) == 736)
        #expect(Board.panelHeight(available: 868) == 836)
        #expect(Board.panelHeight(available: 550) == 518)
    }

    @Test func fixturesHaveCoherentCPUCapacity() {
        for monitor in [PreviewMonitors.cool(), PreviewMonitors.hot()] {
            let average = monitor.coreLoads.map(\.usage).reduce(0, +) / Double(monitor.coreLoads.count)
            #expect(abs((monitor.cpuLoad ?? -1) - average) < 0.00001)
            let measured = monitor.processes.map(\.percent).reduce(0, +)
            #expect(abs(measured + (monitor.hiddenLoad ?? -1) - average * 1200) < 0.00001)
        }
    }

    @Test func utilizationWordsDoNotClaimOverheating() {
        for band in HeatBand.allCases {
            #expect(!["COOL", "WARM", "HOT", "BURN"].contains(band.usageTitle))
        }
    }

    @Test func notificationPreferenceDoesNotImplyAuthorization() {
        #expect(NotificationAccess(status: .notDetermined, alertsEnabled: false) == .notRequested)
        #expect(NotificationAccess(status: .denied, alertsEnabled: false) == .denied)
        #expect(NotificationAccess(status: .authorized, alertsEnabled: false) == .denied)
        #expect(NotificationAccess(status: .authorized, alertsEnabled: true) == .allowed)
    }
}
