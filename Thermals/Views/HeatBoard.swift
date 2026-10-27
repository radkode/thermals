import SwiftUI

struct HeatBoard: View {
    let monitor: Monitor

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            LampMeter(
                readings: monitor.history,
                scale: .temperature,
                level: HeatLevel.init(celsius:),
                unit: "°",
                accessibilityName: "CPU temperature"
            )
            SensorBoard(sensors: monitor.sensors)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                ColumnLabel("CPU DIE")
                FlapText(
                    text: monitor.cpuTemperature.map(Format.degrees) ?? "--°",
                    cells: 3,
                    size: .hero,
                    ink: monitor.cpuTemperature.map { Board.heat(HeatLevel(celsius: $0.rounded())) } ?? Board.steelLight,
                    alignment: .trailing
                )
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 9) {
                BoardStat(
                    label: "LOAD",
                    value: monitor.cpuLoad.map(Format.percent) ?? "--",
                    cells: 4,
                    ink: monitor.cpuLoad.map { Board.heat(HeatLevel(loadPercent: ($0 * 100).rounded())) } ?? Board.steelLight
                )
                BoardStat(label: "PRESSURE", value: monitor.thermalState.boardTitle, cells: 8, ink: monitor.thermalState.ink)
            }
        }
    }
}

struct SensorBoard: View {
    let sensors: [SensorReading]

    static let nameCells = 18
    static let tempCells = 3
    static let statusCells = 4
    static let columnSpacing: CGFloat = 6
    static let rowSpacing: CGFloat = 3
    static let minimumRows = 8

    @Environment(\.snapshotRendering) private var snapshotRendering

    var body: some View {
        BoardPanel {
            VStack(alignment: .leading, spacing: Self.rowSpacing) {
                columns(
                    Color.clear.frame(height: 1),
                    ColumnLabel("SENSOR"),
                    ColumnLabel("°C"),
                    ColumnLabel("STATUS")
                )
                // Takes whatever height the popover gives it; blank flap rows fill what the sensors don't.
                Color.clear
                    .frame(height: Self.height(rows: Self.minimumRows))
                    .frame(maxHeight: .infinity)
                    .overlay(alignment: .top) {
                        GeometryReader { geometry in
                            list(fitting: Self.rowsThatFit(height: geometry.size.height))
                        }
                    }
            }
        }
    }

    @ViewBuilder private func list(fitting fit: Int) -> some View {
        if sensors.count > fit {
            if snapshotRendering {
                rows.frame(height: Self.height(rows: fit), alignment: .top).clipped()
            } else {
                ScrollView(.vertical) { rows }
                    .frame(height: Self.height(rows: fit))
            }
        } else {
            VStack(alignment: .leading, spacing: Self.rowSpacing) {
                if sensors.isEmpty {
                    columns(
                        Lamp(lit: false, color: Board.steelLight),
                        FlapText(text: "UNAVAILABLE", cells: Self.nameCells, ink: Board.steelLight),
                        FlapText(text: "--", cells: Self.tempCells, ink: Board.steelLight, alignment: .trailing),
                        FlapText(text: "", cells: Self.statusCells)
                    )
                }
                ForEach(sensors, id: \.name, content: row)
                ForEach(0..<max(0, fit - max(sensors.count, 1)), id: \.self) { _ in blankRow }
            }
        }
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: Self.rowSpacing) {
            ForEach(sensors, id: \.name, content: row)
        }
    }

    private var blankRow: some View {
        columns(
            Lamp(lit: false, color: Board.steelLight),
            FlapText(text: "", cells: Self.nameCells),
            FlapText(text: "", cells: Self.tempCells),
            FlapText(text: "", cells: Self.statusCells)
        )
        .accessibilityHidden(true)
    }

    static func height(rows: Int) -> CGFloat {
        CGFloat(rows) * FlapSize.row.stripHeight + CGFloat(max(0, rows - 1)) * rowSpacing
    }

    static func rowsThatFit(height: CGFloat) -> Int {
        max(1, Int((height + rowSpacing) / (FlapSize.row.stripHeight + rowSpacing)))
    }

    private func row(_ sensor: SensorReading) -> some View {
        let level = HeatLevel(celsius: sensor.celsius.rounded())
        let band = level.band
        return columns(
            Lamp(lit: band >= .hot, color: Board.heat(level)),
            FlapText(text: sensor.label, cells: Self.nameCells, ink: band == .burn ? Board.heat(level) : Board.steelLight),
            FlapText(text: "\(Int(sensor.celsius.rounded()))", cells: Self.tempCells, ink: Board.heat(level), alignment: .trailing),
            FlapText(text: band.title, cells: Self.statusCells, ink: Board.heat(level))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(sensor.label), \(Format.degrees(sensor.celsius)), \(band.title.lowercased())")
    }

    /// Lamp, name, temperature and status columns at fixed widths, so the header lines up with the scrolling rows.
    private func columns(_ lamp: some View, _ name: some View, _ temp: some View, _ status: some View) -> some View {
        HStack(spacing: Self.columnSpacing) {
            lamp.frame(width: 6)
            name.frame(width: FlapSize.row.stripWidth(cells: Self.nameCells), alignment: .leading)
            temp.frame(width: FlapSize.row.stripWidth(cells: Self.tempCells), alignment: .trailing)
            status.frame(width: FlapSize.row.stripWidth(cells: Self.statusCells), alignment: .leading)
        }
    }
}
