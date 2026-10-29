import Foundation
import Testing
@testable import Thermals

struct HeatActivityTests {
    @Test func idleBackgroundDoesNotRequireProcessScans() {
        #expect(!HeatActivity.shouldSample(celsius: 45, pressure: .nominal, trend: .steady, visible: false))
        #expect(HeatActivity.shouldSample(celsius: 45, pressure: .nominal, trend: .steady, visible: true))
        #expect(HeatActivity.shouldSample(celsius: 76, pressure: .nominal, trend: .steady, visible: false))
        #expect(HeatActivity.shouldSample(celsius: 55, pressure: .nominal, trend: .rising, visible: false))
        #expect(HeatActivity.shouldSample(celsius: nil, pressure: .serious, trend: nil, visible: false))
    }

    @Test func oldAndFutureActivityIsNotPresentedAsCurrent() {
        let now = Date.now
        let sample = HeatActivity(process: ProcessLoad(name: "Xcode", percent: 340), date: now)
        #expect(sample.isFresh(at: now.addingTimeInterval(30)))
        #expect(!sample.isFresh(at: now.addingTimeInterval(46)))
        #expect(!sample.isFresh(at: now.addingTimeInterval(-1)))
    }

    @MainActor @Test func simultaneousConsumersShareOneScanAndRecentCPUResultsAreReused() async {
        let counter = ScanCounter()
        let sampler = ActivitySampler { await counter.read() }
        async let heat = sampler.sample()
        async let peak = sampler.sample()
        async let alert = sampler.sample()
        let values = await [heat, peak, alert]
        #expect(values.allSatisfy { $0.process?.name == "Xcode" })
        #expect(await counter.count == 1)
        sampler.record(ProcessLoad(name: "Safari", percent: 30), at: .now)
        #expect(await sampler.sample().process?.name == "Safari")
        #expect(await counter.count == 1)
    }
}

private actor ScanCounter {
    var count = 0
    func read() async -> ProcessLoad? {
        count += 1
        try? await Task.sleep(for: .milliseconds(20))
        return ProcessLoad(name: "Xcode", percent: 340)
    }
}
