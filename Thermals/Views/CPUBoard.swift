import SwiftUI

/// CPU load explained in heat terms: total load beside the die temperature, cores by cluster, and the processes driving it.
struct CPUBoard: View {
    let monitor: Monitor

    @Environment(\.temperatureUnit) private var unit

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            ReadingNotice(state: monitor.cpuState, source: "CPU load", retry: monitor.refresh)
            BoardNote("Total: 100% = all cores.")
                .help("Whole-system load: 100% means all cores are fully occupied. Load is utilization, not heat.")
            LampMeter(
                readings: monitor.loadHistory,
                scale: .load,
                level: HeatLevel.init(loadPercent:),
                unit: "%",
                accessibilityName: "Whole-system CPU load",
                state: monitor.cpuState,
                utilization: true
            )
            ProcessBoard(processes: monitor.processes, hiddenLoad: monitor.hiddenLoad, state: monitor.processState)
            if !monitor.coreLoads.isEmpty { CoreBoard(cores: monitor.coreLoads) }
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
                    ink: monitor.cpuLoad.map { Board.usage(HeatLevel(loadPercent: ($0 * 100).rounded())) } ?? Board.steelLight,
                    alignment: .trailing
                )
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 9) {
                BoardStat(
                    label: "CPU DIE",
                    value: monitor.cpuTemperature.map { Format.degrees($0, unit: unit) } ?? "--",
                    cells: 4,
                    ink: monitor.menuBarLevel.map { Board.heat($0) } ?? Board.steelLight
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
            Lamp(lit: band >= .hot, color: Board.usage(level))
            FlapText(text: core.name, cells: nameCells, ink: band == .burn ? Board.usage(level) : Board.steelLight)
            LensBar(percent: percent) { floor, lit in
                let level = HeatLevel(loadPercent: floor)
                return lit ? Board.usage(level) : (level.band >= .hot ? Board.usage(level).opacity(0.16) : Board.lens)
            }
            FlapText(text: "\(Int(percent))", cells: 3, ink: Board.usage(level), alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Core \(core.name), \(Int(percent)) percent, \(band.usageTitle.lowercased())")
    }
}

/// Processes ranked by CPU, sliding to their new rank, with the load they can't account for pinned last.
private struct ProcessBoard: View {
    let processes: [ProcessLoad]
    let hiddenLoad: Double?
    let state: ReadingState

    static let rankedRows = 5
    static let nameCells = 15
    static let percentCells = 4
    static let statusCells = 4

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shown = Array(processes.prefix(Self.rankedRows))
        BoardPanel {
            VStack(alignment: .leading, spacing: 3) {
                columns(Color.clear.frame(height: 1), ColumnLabel("TOP PROCESSES"), ColumnLabel("%CPU"), ColumnLabel("LOAD"))
                ReadingNotice(state: state, source: "Processes", empty: shown.isEmpty)
                ForEach(shown) { process in
                    row(name: process.name, percent: process.percent, label: "\(process.name), \(Int(process.percent.rounded())) percent of one CPU core")
                }
                if let hiddenLoad {
                    // An aggregate of many processes, so it is never banded with the per-process thresholds.
                    columns(
                        Lamp(lit: false, color: Board.steelLight),
                        FlapText(text: "UNMEASURED EST", cells: Self.nameCells, ink: Board.steelLight),
                        FlapText(text: "\(Int(hiddenLoad.rounded()))", cells: Self.percentCells, ink: Board.steelLight, alignment: .trailing),
                        FlapText(text: "", cells: Self.statusCells)
                    )
                    .padding(.top, 6)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Estimated unmeasured CPU work, percent of one core, derived from total load, \(Int(hiddenLoad.rounded())) percent CPU")
                }
                BoardNote("100% = one core. Rows are not additive.")
                    .help("Multithreaded apps can exceed 100%. The top five are smoothed. Unmeasured work is estimated from all sampled processes, so these rows do not add up to the headline.")
                    .padding(.top, 5)
            }
            .animation(reduceMotion ? nil : Board.settle, value: shown.map(\.name))
        }
    }

    private func row(name: String, percent: Double, label: String) -> some View {
        let shown = percent.rounded()
        let level = HeatLevel(loadPercent: shown)
        let band = level.band
        return columns(
            Lamp(lit: band >= .hot, color: Board.usage(level)),
            FlapText(text: name, cells: Self.nameCells, ink: band == .burn ? Board.usage(level) : Board.steelLight),
            FlapText(text: "\(Int(shown))", cells: Self.percentCells, ink: Board.usage(level), alignment: .trailing),
            FlapText(text: band.usageTitle, cells: Self.statusCells, ink: Board.usage(level))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private func columns(_ lamp: some View, _ name: some View, _ percent: some View, _ status: some View) -> some View {
        HStack(spacing: 6) {
            lamp.frame(width: 6)
            name.frame(maxWidth: .infinity, alignment: .leading)
            percent.frame(width: FlapSize.row.stripWidth(cells: Self.percentCells), alignment: .trailing)
            status.frame(width: FlapSize.row.stripWidth(cells: Self.statusCells), alignment: .leading)
        }
    }
}
