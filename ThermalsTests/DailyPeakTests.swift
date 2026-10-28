import Foundation
import Testing
@testable import Thermals

struct DailyPeakTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        return calendar
    }()

    /// 2026-10-28 at the given local hour and minute.
    private func at(_ hour: Int, _ minute: Int = 0, day: Int = 28) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    @Test func firstReadingStartsThePeak() {
        let peak = DailyPeak.updated(nil, celsius: 52, at: at(9), calendar: calendar)
        #expect(peak == DailyPeak(celsius: 52, date: at(9)))
    }

    @Test func onlyAHigherDisplayedDegreeReplacesThePeak() {
        let morning = DailyPeak(celsius: 80.2, date: at(9), culprit: "xcodebuild", attributedDate: at(9))
        #expect(DailyPeak.updated(morning, celsius: 80.4, at: at(10), calendar: calendar) == morning)
        #expect(DailyPeak.updated(morning, celsius: 75, at: at(10), calendar: calendar) == morning)
        #expect(DailyPeak.updated(morning, celsius: 81, at: at(11), calendar: calendar).celsius == 81)
    }

    @Test func aRecentCulpritCarriesToAClimbingPeakButAnOldOneIsDropped() {
        let sampled = DailyPeak(celsius: 80, date: at(14), culprit: "xcodebuild", attributedDate: at(14))
        let climbing = DailyPeak.updated(sampled, celsius: 82, at: at(14).addingTimeInterval(40), calendar: calendar)
        #expect(climbing == DailyPeak(celsius: 82, date: at(14).addingTimeInterval(40), culprit: "xcodebuild", attributedDate: at(14)))
        let later = DailyPeak.updated(sampled, celsius: 86, at: at(16), calendar: calendar)
        #expect(later == DailyPeak(celsius: 86, date: at(16)))
    }

    @Test func aPeakOlderThanTheWindowIsNeverAttributedToLaterWork() {
        // Set at 09:00, then the app relaunched at 15:00 before sampling.
        #expect(!DailyPeak(celsius: 88, date: at(9)).needsAttribution(at: at(15), lastSampled: nil))
    }

    @Test func aFailedSampleLeavesThePeakUnattributed() {
        let peak = DailyPeak(celsius: 70, date: at(14))
        #expect(peak.attributed(nil, for: at(14), calendar: calendar) == peak)
        #expect(peak.needsAttribution(at: at(14).addingTimeInterval(30), lastSampled: at(14)))
    }

    @Test func aNewDayStartsOverEvenWhenCooler() {
        let yesterday = DailyPeak(celsius: 92, date: at(23, 50), culprit: "ffmpeg", attributedDate: at(23, 50))
        #expect(DailyPeak.updated(yesterday, celsius: 48, at: at(0, 5, day: 29), calendar: calendar) == DailyPeak(celsius: 48, date: at(0, 5, day: 29)))
    }

    @Test func attributionWaitsForWarmPeaksAndThirtySecondsBetweenSamples() {
        let warm = DailyPeak(celsius: 61, date: at(14))
        #expect(warm.needsAttribution(at: at(14), lastSampled: nil))
        #expect(!warm.needsAttribution(at: at(14).addingTimeInterval(29), lastSampled: at(14)))
        #expect(warm.needsAttribution(at: at(14).addingTimeInterval(30), lastSampled: at(14)))
        #expect(!DailyPeak(celsius: 49.4, date: at(14)).needsAttribution(at: at(14), lastSampled: nil))
    }

    @Test func aPeakAttributedForItsOwnDateNeedsNoNewSample() {
        let attributed = DailyPeak(celsius: 70, date: at(14)).attributed("Xcode", for: at(14), calendar: calendar)
        #expect(attributed.culprit == "Xcode")
        #expect(!attributed.needsAttribution(at: at(14).addingTimeInterval(45), lastSampled: at(14)))
        // The peak rose 40 s after that sample: sample again once allowed.
        let risen = DailyPeak.updated(attributed, celsius: 74, at: at(14).addingTimeInterval(40), calendar: calendar)
        #expect(risen.culprit == "Xcode")
        #expect(risen.needsAttribution(at: at(14).addingTimeInterval(40), lastSampled: at(14)))
    }

    @Test func clockIsTwentyFourHourLocalTime() {
        #expect(Format.clock(at(14, 2), calendar: calendar) == "14:02")
        #expect(Format.clock(at(0, 5, day: 29), calendar: calendar) == "00:05")
    }

    @Test func aSampleFromBeforeMidnightIsNotPinnedOnTheNewDay() {
        let newDay = DailyPeak(celsius: 55, date: at(0, 1, day: 29))
        #expect(newDay.attributed("ffmpeg", for: at(23, 59), calendar: calendar) == newDay)
    }
}
