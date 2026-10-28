import Foundation
import Testing
@testable import Thermals

struct HeatAlertTriggerTests {
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    /// Feeds readings every `step` seconds from `from`, returning the offsets at which the trigger fired.
    private func run(
        _ trigger: inout HeatAlertTrigger,
        celsius: Double?,
        state: ProcessInfo.ThermalState = .nominal,
        from: TimeInterval,
        to: TimeInterval,
        step: TimeInterval = 6
    ) -> [TimeInterval] {
        stride(from: from, through: to, by: step).filter {
            trigger.observe(celsius: celsius, thermalState: state, at: start.addingTimeInterval($0))
        }
    }

    @Test func staysQuietBelowBurn() {
        var trigger = HeatAlertTrigger()
        #expect(run(&trigger, celsius: 89, state: .fair, from: 0, to: 300).isEmpty)
    }

    @Test func firesOnceBurnHasHeldForThirtySeconds() {
        var trigger = HeatAlertTrigger()
        #expect(run(&trigger, celsius: 94, from: 0, to: 120) == [30])
    }

    @Test func aSpikeShorterThanTheSustainWindowStaysQuiet() {
        var trigger = HeatAlertTrigger()
        #expect(run(&trigger, celsius: 95, from: 0, to: 24).isEmpty)
        #expect(run(&trigger, celsius: 70, from: 30, to: 60).isEmpty)
        #expect(run(&trigger, celsius: 95, from: 66, to: 90).isEmpty)
    }

    @Test func seriousPressureAlertsWithoutBurnTemperature() {
        var trigger = HeatAlertTrigger()
        #expect(run(&trigger, celsius: 82, state: .serious, from: 0, to: 60) == [30])
    }

    @Test func coolingOnlyToHotDoesNotStartANewEpisode() {
        var trigger = HeatAlertTrigger()
        #expect(run(&trigger, celsius: 94, from: 0, to: 60) == [30])
        #expect(run(&trigger, celsius: 80, from: 66, to: 600).isEmpty)
        #expect(run(&trigger, celsius: 94, from: 606, to: 1200).isEmpty)
    }

    @Test func coolingBelowHotRearmsAfterTheCooldown() {
        var trigger = HeatAlertTrigger()
        #expect(run(&trigger, celsius: 94, from: 0, to: 60) == [30])
        #expect(run(&trigger, celsius: 60, from: 66, to: 120).isEmpty)
        // Re-armed, but inside ten minutes of the first alert: held until the cooldown passes.
        #expect(run(&trigger, celsius: 94, from: 126, to: 700) == [630])
    }

    @Test func aSleepGapDoesNotCountAsSustainedHeat() {
        var trigger = HeatAlertTrigger()
        #expect(run(&trigger, celsius: 94, from: 0, to: 24).isEmpty)
        #expect(run(&trigger, celsius: 94, from: 3600, to: 3624).isEmpty)
        #expect(run(&trigger, celsius: 94, from: 3630, to: 3660) == [3630])
    }

    @Test func noReadingAndNominalPressureNeverAlerts() {
        var trigger = HeatAlertTrigger()
        #expect(run(&trigger, celsius: nil, from: 0, to: 300).isEmpty)
    }
}

struct HeatAlertMessageTests {
    @Test func namesTheTemperatureAndTheBusiestProcess() {
        let body = HeatAlertMessage.body(celsius: 94.4, unit: .celsius, thermalState: .fair, culprit: ProcessLoad(name: "Xcode", percent: 340.2))
        #expect(body == "CPU 94°. Xcode is using the most CPU (340%).")
    }

    @Test func saysWhenMacOSIsThrottling() {
        let body = HeatAlertMessage.body(celsius: 86, unit: .fahrenheit, thermalState: .serious, culprit: nil)
        #expect(body == "CPU 187°, and macOS is slowing your Mac down to cool it off.")
    }

    @Test func throttlingWithoutATemperatureReading() {
        let body = HeatAlertMessage.body(celsius: nil, unit: .celsius, thermalState: .critical, culprit: ProcessLoad(name: "ffmpeg", percent: 780))
        #expect(body == "macOS is slowing your Mac down to cool it off. ffmpeg is using the most CPU (780%).")
    }
}
