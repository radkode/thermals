import Foundation
import Testing
@testable import Thermals

struct ThermalSessionTests {
    let start = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func energyUsesWattHoursAndIntegratesChangingPower() {
        var session = ThermalSession(at: start)
        for seconds in stride(from: 0.0, through: 60, by: 10) {
            session.observe(at: start.addingTimeInterval(seconds), celsius: 80, pressure: .nominal, watts: 30)
        }
        #expect(abs(session.energyWh - 0.5) < 0.000001)
        #expect(session.powerSeconds == 60)
        #expect(session.observedSeconds == 60)
        #expect(session.pressureSeconds == 0)
        session.observe(at: start.addingTimeInterval(70), celsius: 90, pressure: .serious, watts: 60)
        #expect(abs(session.energyWh - 0.625) < 0.000001)
        #expect(session.peak == 90)
    }

    @Test func sleepAndMissingPowerDoNotBecomeEstimatedEnergy() {
        var session = ThermalSession(at: start)
        for seconds in [0.0, 10, 600, 610] {
            session.observe(at: start.addingTimeInterval(seconds), celsius: nil, pressure: .critical, watts: 36)
        }
        #expect(session.duration == 610)
        #expect(session.observedSeconds == 20)
        #expect(session.pressureSeconds == 20)
        #expect(abs(session.energyWh - 0.2) < 0.000001)
        #expect(session.hasGaps)
        #expect(session.peak == nil)
        session.observe(at: start.addingTimeInterval(620), celsius: 85, pressure: .nominal, watts: nil)
        session.observe(at: start.addingTimeInterval(630), celsius: 84, pressure: .nominal, watts: 36)
        #expect(session.powerSeconds == 20)
    }

    @Test func initialDelayInvalidPowerAndClockChangesPreserveCoverage() {
        var session = ThermalSession(at: start)
        session.observe(at: start.addingTimeInterval(10), celsius: 80, pressure: .serious, watts: .nan)
        #expect(session.observedSeconds == 0)
        session.observe(at: start.addingTimeInterval(20), celsius: 81, pressure: .serious, watts: -1)
        #expect(session.powerSeconds == 0)
        session.observe(at: start.addingTimeInterval(5), celsius: 90, pressure: .serious, watts: 36)
        session.observe(at: start.addingTimeInterval(30), celsius: 83, pressure: .serious, watts: 36)
        #expect(session.observedSeconds == 10)
        #expect(session.powerSeconds == 0)
        #expect(session.hasGaps)
    }

    @Test func explicitStartStopAndRelaunchPreserveTheLatestReceipt() throws {
        var sessions = ThermalSessions()
        sessions.start(at: start)
        sessions.start(at: start.addingTimeInterval(10))
        #expect(sessions.current?.startedAt == start)
        sessions.observe(at: start, celsius: 80, pressure: .nominal, watts: 30)
        sessions.observe(at: start.addingTimeInterval(10), celsius: 85, pressure: .serious, watts: 30)
        sessions.finish()
        #expect(sessions.current == nil)
        #expect(sessions.last?.duration == 10)
        #expect(sessions.last?.interrupted == false)
        sessions.start(at: start.addingTimeInterval(100))
        #expect(sessions.last?.duration == 10)
        sessions.observe(at: start.addingTimeInterval(110), celsius: 70, pressure: .nominal, watts: nil)
        var restored = try JSONDecoder().decode(ThermalSessions.self, from: JSONEncoder().encode(sessions))
        restored.finish(interrupted: true)
        #expect(restored.last?.interrupted == true)
        #expect(restored.last?.endedAt == start.addingTimeInterval(110))
        let receipt = try #require(restored.last?.receipt(unit: .fahrenheit))
        #expect(receipt.contains("Peak CPU: 158°F"))
        #expect(restored.last?.receipt(unit: .celsius).contains("Peak CPU: 70°C") == true)
        #expect(receipt.contains("energy: unavailable"))
        #expect(receipt.contains("No process names included"))
    }
}
