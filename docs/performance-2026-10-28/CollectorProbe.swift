import Foundation

@main struct CollectorProbe {
    @MainActor static func main() async throws {
        let collector = SensorCollector()
        var beats = 0
        var lateness: [Double] = []
        let heartbeat = Task { @MainActor in
            while !Task.isCancelled {
                let start = DispatchTime.now().uptimeNanoseconds
                do { try await Task.sleep(for: .milliseconds(5)) } catch { return }
                lateness.append(max(0, Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6 - 5))
                beats += 1
            }
        }
        var rows: [[String: Any]] = []
        for _ in 0..<20 {
            let before = beats
            let start = DispatchTime.now().uptimeNanoseconds
            let count: Int
            if CommandLine.arguments.contains("--footprints") {
                count = await Task.detached(priority: .utility) { MemoryStats.appFootprints().map(MemoryStats.ranked)?.count ?? 0 }.value
            } else { count = await collector.sample().sensors.count }
            rows.append(["wall_ms": Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6,
                         "main_actor_heartbeats_during_read": beats - before, "readings": count])
            try await Task.sleep(for: .milliseconds(100))
        }
        heartbeat.cancel()
        await heartbeat.value
        let report: [String: Any] = ["samples": rows, "heartbeat_lateness_ms": lateness]
        print(String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self))
    }
}
