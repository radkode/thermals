import SwiftUI

/// CPU load explained in heat terms: total load beside the die temperature, cores by cluster, and the processes driving it.
struct CPUBoard: View {
    let monitor: Monitor

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            LampMeter(
                values: monitor.loadHistory,
                rowFloors: LampMeter.loadRows,
                band: HeatBand.init(loadPercent:),
                unit: "%",
                accessibilityName: "CPU load"
            )
            CoreBoard(cores: monitor.coreLoads)
            ProcessBoard(processes: monitor.processes)
        }
        .onAppear { monitor.samplesProcesses = true }
        .onDisappear { monitor.samplesProcesses = false }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                ColumnLabel("CPU LOAD")
                FlapText(
                    text: monitor.cpuLoad.map(Format.percent) ?? "--%",
                    cells: 4,
                    size: .hero,
                    ink: monitor.cpuLoad.map { Board.heroInk(for: HeatBand(loadPercent: $0 * 100)) } ?? Board.steelLight,
                    alignment: .trailing
                )
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 9) {
                BoardStat(
                    label: "CPU DIE",
                    value: monitor.cpuTemperature.map(Format.degrees) ?? "--",
                    cells: 4,
                    ink: monitor.cpuTemperature.map { Board.ink(for: HeatBand(celsius: $0)) } ?? Board.steelLight
                )
                BoardStat(label: "PRESSURE", value: monitor.thermalState.boardTitle, cells: 8, ink: monitor.thermalState.ink)
            }
        }
    }
}

/// Cores as two platforms side by side: performance and efficiency, each core a row in fixed order.
private struct CoreBoard: View {
    let cores: [CoreLoad]

    var body: some View {
        BoardPanel {
            if cores.isEmpty {
                ColumnLabel("COLLECTING READINGS")
                    .frame(maxWidth: .infinity, minHeight: 40)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(platforms, id: \.title) { platform in
                        VStack(alignment: .leading, spacing: 3) {
                            ColumnLabel(platform.title)
                            ForEach(platform.cores) { CoreRow(core: $0) }
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

    var body: some View {
        let percent = core.usage * 100
        let band = HeatBand(loadPercent: percent)
        HStack(spacing: 5) {
            FlapText(text: core.name, cells: 3, ink: Board.steelLight)
            LoadBar(percent: percent)
            FlapText(text: "\(Int(percent.rounded()))", cells: 3, ink: Board.ink(for: band), alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Core \(core.name), \(Int(percent.rounded())) percent")
    }
}

/// A short row of lamps lit up to the load, each lamp tinted by the band it stands for.
private struct LoadBar: View {
    let percent: Double

    var body: some View {
        Canvas { context, size in
            let floors = LampMeter.loadRows
            let gap: CGFloat = 1.5
            let width = (size.width - gap * CGFloat(floors.count - 1)) / CGFloat(floors.count)
            for (index, floor) in floors.enumerated() {
                let band = HeatBand(loadPercent: floor)
                let lit = percent >= floor
                let rect = CGRect(x: CGFloat(index) * (width + gap), y: 0, width: width, height: size.height)
                let lens = lit ? Board.ink(for: band) : (band >= .hot ? Board.ink(for: band).opacity(0.16) : Board.lens)
                context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(lens))
            }
        }
        .frame(height: 10)
        .frame(maxWidth: .infinity)
    }
}

/// The user's processes ranked by CPU; rows slide to their new rank instead of jumping.
private struct ProcessBoard: View {
    let processes: [ProcessLoad]

    static let visibleRows = 6
    static let nameCells = 11
    static let percentCells = 4
    static let statusCells = 4

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shown = Array(processes.prefix(Self.visibleRows))
        BoardPanel {
            VStack(alignment: .leading, spacing: 3) {
                columns(Color.clear, ColumnLabel("YOUR PROCESSES"), ColumnLabel("%CPU"), ColumnLabel("STATUS"))
                if shown.isEmpty {
                    columns(
                        Lamp(lit: false, color: Board.steelLight),
                        FlapText(text: "SAMPLING", cells: Self.nameCells, ink: Board.steelLight),
                        FlapText(text: "--", cells: Self.percentCells, ink: Board.steelLight, alignment: .trailing),
                        FlapText(text: "", cells: Self.statusCells)
                    )
                } else {
                    ForEach(shown) { process in row(process) }
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: shown.map(\.name))
        }
    }

    private func row(_ process: ProcessLoad) -> some View {
        let band = HeatBand(loadPercent: process.percent)
        return columns(
            Lamp(lit: band >= .hot, color: Board.ink(for: band)),
            FlapText(text: process.name, cells: Self.nameCells, ink: band == .burn ? Board.burnRed : Board.steelLight),
            FlapText(text: "\(Int(process.percent.rounded()))", cells: Self.percentCells, ink: Board.ink(for: band), alignment: .trailing),
            FlapText(text: band.title, cells: Self.statusCells, ink: Board.ink(for: band))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(process.name), \(Int(process.percent.rounded())) percent CPU")
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
