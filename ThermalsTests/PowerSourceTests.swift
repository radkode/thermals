import IOKit.ps
import Testing
@testable import Thermals

struct PowerSourceTests {
    @Test func distinguishesBatteryChargingAndAttachedButNotCharging() {
        let battery: [String: Any] = [kIOPSTypeKey: kIOPSInternalBatteryType, kIOPSIsPresentKey: true]
        #expect(PowerSourceReading.interpret(sources: [battery], providing: kIOPSBatteryPowerValue, adapterWatts: 96).state == .battery)
        #expect(PowerSourceReading.interpret(sources: [battery], providing: kIOPSBatteryPowerValue, adapterWatts: 96).adapterWatts == nil)
        for charging in [true, false] {
            var details = battery
            details[kIOPSIsChargingKey] = charging
            let reading = PowerSourceReading.interpret(sources: [details], providing: kIOPSACPowerValue, adapterWatts: 96)
            #expect(reading.state == (charging ? .charging : .pluggedIn))
            #expect(reading.adapterWatts == 96)
        }
    }

    @Test func missingKeysAndDesktopsDoNotInventCharging() {
        #expect(PowerSourceReading.interpret(sources: [], providing: kIOPSACPowerValue, adapterWatts: nil).state == .external)
        #expect(PowerSourceReading.interpret(sources: [], providing: nil, adapterWatts: 96).state == .unavailable)
        for watts in [Double.nan, .infinity, -1, 0, 1000] {
            #expect(PowerSourceReading.interpret(sources: [], providing: kIOPSACPowerValue, adapterWatts: watts).adapterWatts == nil)
        }
    }
}
