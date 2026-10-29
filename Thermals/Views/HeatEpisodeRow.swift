import SwiftUI

struct HeatEpisodeRow: View {
    let recorder: HeatEpisodeRecorder
    @Environment(\.temperatureUnit) private var unit

    var body: some View {
        if let episode = recorder.current ?? recorder.recent.first {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(([recorder.current].compactMap { $0 } + recorder.recent)) { item in
                        BoardNote(description(item))
                    }
                    BoardNote("Pressure time counts intervals observed as serious or critical at both ends. Activity is not proof of heat causation.")
                }.padding(.top, 6)
            } label: {
                HStack(spacing: 6) {
                    ColumnLabel(recorder.current == nil ? "LAST HEAT" : "HEAT NOW")
                    Spacer(minLength: 0)
                    FlapText(text: Format.clock(episode.startedAt), cells: 5, ink: Board.steelLight)
                    FlapText(text: episode.duration < 60 ? "\(Int(episode.duration))S" : "\(Int(episode.duration / 60))M", cells: 4, ink: Board.steelLight, alignment: .trailing)
                    FlapText(text: episode.peak.map { Format.degrees($0, unit: unit) } ?? "--", cells: 4, alignment: .trailing)
                }
            }
            .tint(Board.steelLight)
            .help("Inspect recent heat episodes. Starts at 85°C or serious pressure; ends after 30 seconds below 75°C without serious pressure. Up to eight completed episodes are kept on this Mac.")
        }
    }

    private func description(_ episode: HeatEpisode) -> String {
        let power = episode.systemWatts.map { " Peak system \(Format.watts($0))." } ?? ""
        let gpu = episode.gpuWatts.map { " Peak GPU \(Format.watts($0))." } ?? ""
        let activity = episode.topCPU.map { " Top CPU sampled: \($0)." } ?? ""
        return "\(Format.clock(episode.startedAt)) · \(Format.duration(episode.duration)) observed · peak \(episode.peak.map { Format.degrees($0, unit: unit) } ?? "unavailable"). Serious/critical pressure: \(Format.duration(episode.pressureSeconds)).\(power)\(gpu)\(activity)\(episode.interrupted ? " Recording interrupted; unobserved time excluded." : "")"
    }
}
