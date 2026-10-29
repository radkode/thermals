import Foundation
import Testing
@testable import Thermals

struct HeatEpisodeTests {
    let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func read(_ recorder: inout HeatEpisodeRecorder, _ seconds: Double, _ temperature: Double? = 90,
                      _ pressure: ProcessInfo.ThermalState = .nominal) {
        recorder.observe(at: start.addingTimeInterval(seconds), celsius: temperature, pressure: pressure,
                         systemWatts: 30, gpuWatts: 5, activity: nil)
    }

    @Test func temperatureAndOSPressureAreIndependent() {
        var recorder = HeatEpisodeRecorder()
        read(&recorder, 0, 90)
        read(&recorder, 10, 92)
        #expect(recorder.current?.peak == 92)
        #expect(recorder.current?.pressureSeconds == 0)
        read(&recorder, 20, 70, .serious)
        read(&recorder, 30, 70, .serious)
        #expect(recorder.current?.pressureSeconds == 10)
    }

    @Test func recoveryRequiresThirtyContinuousSeconds() {
        var recorder = HeatEpisodeRecorder()
        read(&recorder, 0)
        read(&recorder, 10, 70)
        read(&recorder, 30, 76)
        read(&recorder, 40, 70)
        read(&recorder, 60, 70)
        #expect(recorder.recent.isEmpty)
        read(&recorder, 70, 70)
        #expect(recorder.current == nil)
        #expect(recorder.recent.first?.duration == 70)
        #expect(recorder.recent.first?.interrupted == false)
    }

    @Test func sleepMissingTemperatureAndRestartDoNotInventCoverage() throws {
        var recorder = HeatEpisodeRecorder()
        read(&recorder, 0, 90, .serious)
        read(&recorder, 10, 91, .serious)
        read(&recorder, 600, 90, .serious)
        #expect(recorder.recent.first?.duration == 10)
        #expect(recorder.recent.first?.pressureSeconds == 10)
        #expect(recorder.recent.first?.interrupted == true)
        read(&recorder, 610, nil)
        #expect(recorder.current == nil)
        read(&recorder, 620, nil, .critical)
        #expect(recorder.current?.peak == nil)
        var restored = try JSONDecoder().decode(HeatEpisodeRecorder.self, from: JSONEncoder().encode(recorder))
        restored.finish(interrupted: true)
        #expect(restored.current == nil)
        #expect(restored.recent.first?.duration == 0)
    }

    @Test func retentionIsBoundedAndStaleProcessesAreNotAttributed() {
        var recorder = HeatEpisodeRecorder()
        for index in 0..<12 {
            recorder.observe(at: start.addingTimeInterval(Double(index) * 100), celsius: 90, pressure: .nominal,
                             systemWatts: nil, gpuWatts: nil,
                             activity: HeatActivity(process: ProcessLoad(name: "Old build", percent: 300), date: start.addingTimeInterval(-90)))
            recorder.finish(interrupted: true)
        }
        #expect(recorder.recent.count == 8)
        #expect(recorder.recent.allSatisfy { $0.topCPU == nil })
    }
}
