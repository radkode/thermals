import SwiftUI

/// Memory utilization, OS pressure, and the apps holding physical memory.
struct RAMBoard: View {
    let monitor: Monitor

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            ReadingNotice(state: monitor.memoryState, source: "Memory", retry: monitor.refresh)
            if let memory = monitor.memory {
                BoardNote("\(Format.gigabytes(memory.used)) of \(Format.gigabytes(memory.total)) GB used. OS pressure indicates memory strain; usage alone does not.")
            }
            LampMeter(
                readings: monitor.memoryHistory,
                scale: .memory,
                level: HeatLevel.init(memoryPercent:),
                unit: "%",
                accessibilityName: "Memory used",
                state: monitor.memoryState,
                utilization: true
            )
            BreakdownBoard(memory: monitor.memory)
            AppMemoryBoard(apps: monitor.appMemory, total: monitor.memory?.total, state: monitor.appMemoryState)
        }
    }

    private var header: some View {
        let memory = monitor.memory
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                ColumnLabel("MEMORY USED")
                FlapText(
                    text: memory.map { Format.percent($0.usedPercent / 100) } ?? "--%",
                    cells: 4,
                    size: .hero,
                    ink: memory.map { Board.heat(HeatLevel.memory(usedPercent: $0.usedPercent, pressure: $0.pressure)) } ?? Board.steelLight,
                    alignment: .trailing
                )
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 9) {
                BoardStat(
                    label: "SWAP",
                    value: memory?.swapUsed.map { Format.gigabytes($0) + "G" } ?? "--",
                    cells: 5,
                    ink: (memory?.swapUsed ?? 0) > 0 ? Board.letterWhite : Board.steelLight
                )
                BoardStat(
                    label: "PRESSURE",
                    value: memory?.pressure?.boardTitle ?? "--",
                    cells: 8,
                    ink: memory?.pressure?.ink ?? Board.steelLight
                )
            }
        }
    }
}

/// Physical memory as fixed departures: the three parts that count as used, then the two the system can reclaim.
struct BreakdownBoard: View {
    let memory: MemoryReading?

    static let nameCells = 10
    static let valueCells = 4

    var body: some View {
        BoardPanel {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    ColumnLabel("MEMORY").frame(width: FlapSize.row.stripWidth(cells: Self.nameCells) + 11, alignment: .leading)
                    ColumnLabel("SHARE")
                    Spacer()
                    ColumnLabel("GB")
                }
                let lenses = Self.lenses(shares: parts.map { share(of: $0.bytes) })
                ForEach(Array(parts.enumerated()), id: \.element.name) { index, part in
                    row(part, lenses: lenses[index])
                }
                BoardNote("App, wired and compressed count as used. Cached files can be reclaimed; free memory is unused.")
            }
        }
    }

    /// Each lens is an eighth of physical memory, apportioned by largest remainder so the bars together never light more than the whole.
    static func lenses(shares percents: [Double]) -> [Int] {
        let count = LampMeter.loadRows.count
        let exact = percents.map { max(0, $0) / 100 * Double(count) }
        var lit = exact.map { Int($0) }
        let total = min(count, Int(exact.reduce(0, +).rounded()))
        let byRemainder = exact.indices.sorted { exact[$0] - Double(lit[$0]) > exact[$1] - Double(lit[$1]) }
        for index in byRemainder.prefix(max(0, total - lit.reduce(0, +))) { lit[index] += 1 }
        return lit
    }

    private func share(of bytes: UInt64?) -> Double {
        guard let bytes, let total = memory?.total, total > 0 else { return 0 }
        return Double(bytes) / Double(total) * 100
    }

    private var parts: [(name: String, bytes: UInt64?, used: Bool)] {
        [
            ("APP", memory?.app, true),
            ("WIRED", memory?.wired, true),
            ("COMPRESSED", memory?.compressed, true),
            ("CACHED", memory?.cached, false),
            ("FREE", memory?.free, false),
        ]
    }

    private func row(_ part: (name: String, bytes: UInt64?, used: Bool), lenses: Int) -> some View {
        let share = share(of: part.bytes)
        let ink = part.used ? Board.steelLight : Board.steelMid
        return HStack(spacing: 5) {
            Lamp(lit: false, color: Board.steelLight)
            FlapText(text: part.name, cells: Self.nameCells, ink: Board.steelLight)
            LensBar(lit: lenses) { _, lit in lit ? ink : Board.lens }
            FlapText(text: part.bytes.map(Format.gigabytes) ?? "--", cells: Self.valueCells, ink: part.used ? Board.letterWhite : Board.steelLight, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(part.name.capitalized), \(part.bytes.map(Format.gigabytes) ?? "unavailable") gigabytes, \(Int(share.rounded())) percent of memory")
    }
}

/// The ten largest app footprints, labeled by their share of physical memory.
private struct AppMemoryBoard: View {
    let apps: [AppMemory]
    let total: UInt64?
    let state: ReadingState

    static let nameCells = 15
    static let valueCells = 4
    static let statusCells = 4

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shown = Array(apps.prefix(10))
        return BoardPanel {
            VStack(alignment: .leading, spacing: SensorBoard.rowSpacing) {
                columns(Color.clear.frame(height: 1), ColumnLabel("TOP APPS"), ColumnLabel("GB"), ColumnLabel("SHARE"))
                ReadingNotice(state: state, source: "Apps", empty: shown.isEmpty)
                ForEach(shown, content: row)
                BoardNote("Up to ten apps, by physical footprint. Share is a portion of installed RAM, not a heat warning; app footprints do not add up to total memory used.")
                    .padding(.top, 5)
            }
            .animation(reduceMotion ? nil : Board.settle, value: shown.map(\.name))
        }
    }

    private func row(_ app: AppMemory) -> some View {
        // Without the physical total there is no share to band by, so the row stays neutral.
        let level = total.flatMap { $0 > 0 ? HeatLevel(appMemoryPercent: (Double(app.bytes) / Double($0) * 100).rounded()) : nil }
        let band = level?.band
        let ink = level.map { Board.usage($0) } ?? Board.steelLight
        return columns(
            Lamp(lit: (band ?? .cool) >= .hot, color: ink),
            FlapText(text: app.name, cells: Self.nameCells, ink: band == .burn ? ink : Board.steelLight),
            FlapText(text: Format.gigabytes(app.bytes), cells: Self.valueCells, ink: ink, alignment: .trailing),
            FlapText(text: band?.usageTitle ?? "", cells: Self.statusCells, ink: ink)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(app.name), \(Format.gigabytes(app.bytes)) gigabytes\(band.map { ", \($0.usageTitle.lowercased() + " share of installed RAM")" } ?? "")")
    }

    private func columns(_ lamp: some View, _ name: some View, _ value: some View, _ status: some View) -> some View {
        HStack(spacing: 6) {
            lamp.frame(width: 6)
            name.frame(maxWidth: .infinity, alignment: .leading)
            value.frame(width: FlapSize.row.stripWidth(cells: Self.valueCells), alignment: .trailing)
            status.frame(width: FlapSize.row.stripWidth(cells: Self.statusCells), alignment: .leading)
        }
    }
}
