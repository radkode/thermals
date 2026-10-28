import Foundation
import Testing
@testable import Thermals

struct GPUPowerTests {
    private func sample(_ energy: Int64, unit: String = "nJ", at seconds: Double) -> EnergySample {
        EnergySample(energy: energy, unit: unit, uptimeNanoseconds: UInt64(seconds * 1e9))
    }

    @Test(arguments: [("mJ", 1e-3), ("uJ", 1e-6), ("µJ", 1e-6), ("nJ", 1e-9)])
    func knownEnergyUnits(label: String, joules: Double) {
        #expect(GPUPower.joules(perUnit: label) == joules)
    }

    @Test func unknownUnitIsNil() {
        #expect(GPUPower.joules(perUnit: "kWh") == nil)
    }

    @Test func wattsAreEnergyOverElapsedTime() {
        // 4 J over 2 s in nanojoules.
        #expect(GPUPower.watts(from: sample(1_000_000_000, at: 10), to: sample(5_000_000_000, at: 12)) == 2)
        #expect(GPUPower.watts(from: sample(100, unit: "mJ", at: 0), to: sample(30_100, unit: "mJ", at: 6)) == 5)
    }

    @Test func backwardsCounterStalledClockOrMixedUnitsAreNil() {
        #expect(GPUPower.watts(from: sample(5_000, at: 10), to: sample(4_000, at: 12)) == nil)
        #expect(GPUPower.watts(from: sample(1_000, at: 10), to: sample(5_000, at: 10)) == nil)
        #expect(GPUPower.watts(from: sample(1_000, unit: "mJ", at: 0), to: sample(5_000, at: 2)) == nil)
    }

    @Test func overflowingDeltaIsNil() {
        #expect(GPUPower.watts(from: sample(.min, at: 0), to: sample(.max, at: 1)) == nil)
    }

    @Test func aCounterGoingBackwardsDoesNotCountAsMoving() {
        var meter = GPUPowerMeter()
        #expect(meter.watts(sample(100, at: 0)) == nil)
        #expect(meter.watts(sample(50, at: 2)) == nil)
        #expect(meter.watts(sample(50, at: 4)) == nil)
    }

    @Test func implausibleWattsAreNil() {
        // 1,000 J in one second is a 1 kW GPU.
        #expect(GPUPower.watts(from: sample(0, unit: "mJ", at: 0), to: sample(1_000_000, unit: "mJ", at: 1)) == nil)
    }

    @Test func meterWaitsForABaselineAndForTheCounterToMove() {
        var meter = GPUPowerMeter()
        #expect(meter.watts(sample(1_000, at: 0)) == nil)
        // A frozen counter is unavailable, not an idle 0 W.
        #expect(meter.watts(sample(1_000, at: 2)) == nil)
        #expect(meter.watts(sample(1_000, at: 4)) == nil)
        #expect(meter.watts(sample(2_000_001_000, at: 6)) == 1)
        // Once it has moved, a quiet interval is a real 0 W.
        #expect(meter.watts(sample(2_000_001_000, at: 8)) == 0)
    }
}
