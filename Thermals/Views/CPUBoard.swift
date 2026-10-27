import SwiftUI

/// CPU load explained in heat terms: total load beside the die temperature, cores by cluster, and the processes driving it.
struct CPUBoard: View {
    let monitor: Monitor

    @Environment(\.temperatureUnit) private var unit

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            LampMeter(
                readings: monitor.loadHistory,
                scale: .load,
                level: HeatLevel.init(loadPercent:),
                unit: "%",
                accessibilityName: "CPU load"
            )
            CoreBoard(cores: monitor.coreLoads)
            ProcessBoard(processes: monitor.processes, hiddenLoad: monitor.hiddenLoad)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                ColumnLabel("CPU LOAD")
                FlapText(
                    text: monitor.cpuLoad.map(Format.percent) ?? "--%",
                    cells: 4,
                    size: .hero,
                    ink: monitor.cpuLoad.map { Board.heat(HeatLevel(loadPercent: ($0 * 100).rounded())) } ?? Board.steelLight,
                    alignment: .trailing
                )
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 9) {
                BoardStat(
                    label: "CPU DIE",
                    value: monitor.cpuTemperature.map { Format.degrees($0, unit: unit) } ?? "--",
                    cells: 4,
                    ink: monitor.cpuTemperature.map { Board.heat(HeatLevel(celsius: $0.rounded())) } ?? Board.steelLight
                )
                BoardStat(label: "PRESSURE", value: monitor.thermalState.boardTitle, cells: 8, ink: monitor.thermalState.ink)
            }
        }
    }
}

/// Cores as two platforms side by side: performance and efficiency, each core a departure row in fixed order.
private struct CoreBoard: View {
    let cores: [CoreLoad]

    var body: some View {
        BoardPanel {
            if cores.isEmpty {
                ColumnLabel("COLLECTING READINGS")
                    .frame(maxWidth: .infinity, minHeight: 40)
            } else {
                let nameCells = max(2, cores.map(\.name.count).max() ?? 2)
                HStack(alignment: .top, spacing: 12) {
                    ForEach(platforms, id: \.title) { platform in
                        VStack(alignment: .leading, spacing: 3) {
                            ColumnLabel(platform.title)
                            ForEach(platform.cores) { CoreRow(core: $0, nameCells: nameCells) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var platforms: [(title: String, cores: [CoreLoad])] {
        let performance = cores.filter { $0.cluster == .performance }
        let efficiency = cores.filter { $0.cluster == .efficiency }
        if !performance.isEmpty || !efficiency.isEmpty {
            return [("PERFORMANCE", performance), ("EFFICIENCY", efficiency)].filter { !$0.1.isEmpty }
        }
        let half = (cores.count + 1) / 2
        return [("CORES", Array(cores.prefix(half))), ("", Array(cores.dropFirst(half)))].filter { !$0.1.isEmpty }
    }
}

private struct CoreRow: View {
    let core: CoreLoad
    let nameCells: Int

    var body: some View {
        let percent = (core.usage * 100).rounded()
        let level = HeatLevel(loadPercent: percent)
        let band = level.band
        HStack(spacing: 5) {
            Lamp(lit: band >= .hot, color: Board.heat(level))
            FlapText(text: core.name, cells: nameCells, ink: band == .burn ? Board.heat(level) : Board.steelLight)
            LensBar(percent: percent) { floor, lit in
                let level = HeatLevel(loadPercent: floor)
                return lit ? Board.heat(level) : (level.band >= .hot ? Board.heat(level).opacity(0.16) : Board.lens)
            }
            FlapText(text: "\(Int(percent))", cells: 3, ink: Board.heat(level), alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Core \(core.name), \(Int(percent)) percent, \(band.title.lowercased())")
    }
}

/// Processes ranked by CPU, sliding to their new rank, with the load they can't account for pinned last.
private struct ProcessBoard: View {
    let processes: [ProcessLoad]
    let hiddenLoad: Double?

    static let rankedRows = 5
    static let nameCells = 17
    static let percentCells = 4
    static let statusCells = 4

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shown = Array(processes.prefix(Self.rankedRows))
        BoardPanel {
            VStack(alignment: .leading, spacing: 3) {
                columns(Color.clear.frame(height: 1), ColumnLabel("PROCESSES"), ColumnLabel("%CPU"), ColumnLabel("STATUS"))
                if shown.isEmpty {
                    columns(
                        Lamp(lit: false, color: Board.steelLight),
                        FlapText(text: "SAMPLING", cells: Self.nameCells, ink: Board.steelLight),
                        FlapText(text: "--", cells: Self.percentCells, ink: Board.steelLight, alignment: .trailing),
                        FlapText(text: "", cells: Self.statusCells)
                    )
                } else {
                    ForEach(shown) { process in
                        row(name: process.name, percent: process.percent, label: "\(process.name), \(Int(process.percent.rounded())) percent CPU")
                    }
                }
                if let hiddenLoad {
                    // An aggregate of many processes, so it is never banded with the per-process thresholds.
                    columns(
                        Lamp(lit: false, color: Board.steelLight),
                        FlapText(text: "KERNEL + OTHERS", cells: Self.nameCells, ink: Board.steelLight),
                        FlapText(text: "\(Int(hiddenLoad.rounded()))", cells: Self.percentCells, ink: Board.steelLight, alignment: .trailing),
                        FlapText(text: "", cells: Self.statusCells)
                    )
                    .padding(.top, 6)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Kernel and short-lived processes, derived from total load, \(Int(hiddenLoad.rounded())) percent CPU")
                }
            }
            .animation(reduceMotion ? nil : Board.settle, value: shown.map(\.name))
        }
    }

    private func row(name: String, percent: Double, label: String) -> some View {
        let shown = percent.rounded()
        let level = HeatLevel(loadPercent: shown)
        let band = level.band
        return columns(
            Lamp(lit: band >= .hot, color: Board.heat(level)),
            FlapText(text: name, cells: Self.nameCells, ink: band == .burn ? Board.heat(level) : Board.steelLight),
            FlapText(text: "\(Int(shown))", cells: Self.percentCells, ink: Board.heat(level), alignment: .trailing),
            FlapText(text: band.title, cells: Self.statusCells, ink: Board.heat(level))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private func columns(_ lamp: some View, _ name: some View, _ percent: some View, _ status: some View) -> some View {
        HStack(spacing: 6) {
            lamp.frame(width: 6)
            name.frame(width: FlapSize.row.stripWidth(cells: Self.nameCells), alignment: .leading)
            percent.frame(width: FlapSize.row.stripWidth(cells: Self.percentCells), alignment: .trailing)
            status.frame(width: FlapSize.row.stripWidth(cells: Self.statusCells), alignment: .leading)
        }
    }
}
