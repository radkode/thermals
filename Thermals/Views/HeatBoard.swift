import SwiftUI

struct HeatBoard: View {
    let monitor: Monitor
    var inspectCPU: () -> Void = {}

    @Environment(\.temperatureUnit) private var unit

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            ReadingNotice(state: monitor.temperatureState, source: "CPU temperature", retry: monitor.refresh)
            HStack {
                BoardNote("Pressure: macOS assessment.")
                    .help("Thermal pressure is macOS's assessment, not a temperature limit.")
                Spacer(minLength: 8)
                FlapButton(title: "CPU", accessibilityName: "Inspect current CPU activity", action: inspectCPU)
            }
            LampMeter(
                readings: monitor.history,
                scale: .temperature,
                level: HeatLevel.init(celsius:),
                unit: "°",
                accessibilityName: "CPU temperature",
                state: monitor.temperatureState,
                display: unit.value
            )
            if !monitor.fans.isEmpty { FanBoard(fans: monitor.fans) }
            ReadingNotice(state: monitor.fanState, source: "Fan readings", retry: monitor.refresh)
            SensorBoard(sensors: monitor.sensors)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                ColumnLabel("CPU DIE")
                FlapText(
                    text: monitor.cpuTemperature.map { Format.degrees($0, unit: unit) } ?? "--°",
                    cells: 4,
                    size: .hero,
                    ink: monitor.menuBarLevel.map { Board.heat($0) } ?? Board.steelLight,
                    alignment: .trailing
                )
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 9) {
                HStack(alignment: .top, spacing: 12) {
                    // Watts have no scale shared across chips, so power stays neutral rather than claim a heat color.
                    BoardStat(
                        label: "POWER",
                        value: monitor.systemPower.map(Format.watts) ?? "--",
                        cells: 4,
                        ink: monitor.systemPower == nil ? Board.steelLight : Board.letterWhite
                    )
                    BoardStat(
                        label: "LOAD",
                        value: monitor.cpuLoad.map(Format.percent) ?? "--",
                        cells: 4,
                        ink: monitor.cpuLoad.map { Board.usage(HeatLevel(loadPercent: ($0 * 100).rounded())) } ?? Board.steelLight
                    )
                }
                BoardStat(label: "PRESSURE", value: monitor.thermalState.boardTitle, cells: 8, ink: monitor.thermalState.ink)
            }
        }
    }
}

/// Fans in fixed order, each lit on the heat gradient by how far it is through its speed range.
private struct FanBoard: View {
    let fans: [FanReading]

    static let nameCells = 5
    static let rpmCells = 5

    var body: some View {
        BoardPanel {
            VStack(alignment: .leading, spacing: SensorBoard.rowSpacing) {
                HStack {
                    ColumnLabel("FANS").padding(.leading, 11)
                    Spacer()
                    ColumnLabel("RPM")
                }
                ForEach(fans, content: row)
            }
        }
    }

    private func row(_ fan: FanReading) -> some View {
        // A fan's share of its range reads on the load scale, the same floors its lens bar lights at.
        let percent = (fan.fraction ?? 0) * 100
        let level = fan.fraction.map { _ in HeatLevel(loadPercent: percent.rounded()) }
        let ink = level.map { Board.usage($0) } ?? Board.steelLight
        let rpm = fan.rpm.map { "\(Int($0.rounded()))" } ?? "--"
        return HStack(spacing: 5) {
            Lamp(lit: (level?.band ?? .cool) >= .hot, color: ink)
            FlapText(text: "FAN \(fan.id)", cells: Self.nameCells, ink: level?.band == .burn ? ink : Board.steelLight)
            LensBar(percent: fan.fraction == nil ? 0 : percent) { floor, lit in
                let level = HeatLevel(loadPercent: floor)
                return lit ? Board.usage(level) : (level.band >= .hot ? Board.usage(level).opacity(0.16) : Board.lens)
            }
            FlapText(text: rpm, cells: Self.rpmCells, ink: ink, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fan \(fan.id), \(fan.rpm.map { "\(Int($0.rounded())) RPM" } ?? "unavailable")\(level.map { ", \($0.band.usageTitle.lowercased()) speed" } ?? "")")
    }
}

struct SensorBoard: View {
    let sensors: [SensorReading]

    static let nameCells = 16
    static let tempCells = 3
    static let statusCells = 4
    static let columnSpacing: CGFloat = 6
    static let rowSpacing: CGFloat = 3

    @Environment(\.temperatureUnit) private var unit

    var body: some View {
        BoardPanel {
            VStack(alignment: .leading, spacing: Self.rowSpacing) {
                columns(
                    Color.clear.frame(height: 1),
                    ColumnLabel("SENSOR"),
                    ColumnLabel(unit.title),
                    ColumnLabel("STATUS")
                )
                ForEach(sensors, id: \.name, content: row)
                if sensors.isEmpty { BoardNote("No temperature sensors available.") }
                BoardNote("CPU bands are reference ranges.")
                    .help("Bands apply only to CPU die sensors, not hardware safety limits.")
            }
        }
    }

    private func row(_ sensor: SensorReading) -> some View {
        let level = HeatLevel(celsius: sensor.celsius.rounded())
        let band = level.band
        let isCPU = sensor.name.hasPrefix("PMU tdie")
        let ink = isCPU ? Board.heat(level) : Board.steelLight
        return columns(
            Lamp(lit: isCPU && band >= .hot, color: ink),
            FlapText(text: sensor.label, cells: Self.nameCells, ink: isCPU && band == .burn ? ink : Board.steelLight),
            FlapText(text: "\(Int(unit.value(sensor.celsius).rounded()))", cells: Self.tempCells, ink: ink, alignment: .trailing),
            FlapText(text: isCPU ? band.title : "", cells: Self.statusCells, ink: ink)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(sensor.label), \(Format.degrees(sensor.celsius, unit: unit)), \(isCPU ? band.title.lowercased() + " CPU reference band" : "unbanded reading")")
    }

    /// Lamp, name, temperature and status columns at fixed widths, so the header lines up with the scrolling rows.
    private func columns(_ lamp: some View, _ name: some View, _ temp: some View, _ status: some View) -> some View {
        HStack(spacing: Self.columnSpacing) {
            lamp.frame(width: 6)
            name.frame(maxWidth: .infinity, alignment: .leading)
            temp.frame(width: FlapSize.row.stripWidth(cells: Self.tempCells), alignment: .trailing)
            status.frame(width: FlapSize.row.stripWidth(cells: Self.statusCells), alignment: .leading)
        }
    }
}
