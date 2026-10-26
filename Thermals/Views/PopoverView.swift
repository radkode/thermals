/*
 THESIS: A rail concourse departure board where sensors are departures ranked by heat; refuses the stock stats popover of gauges, rings and system-gray rows.
 OWN-WORLD: Matte flap cells with a hinge gap and axle pins in black housings on a steel frame; Barlow Condensed caps; steel light for cool, letter white for warm, amber lamps for hot, red type for burn.
 STORY: One glance at the big flaps says how hot the CPU is; the ranked board says which sensor is driving it; the lamp meter says whether it is climbing.
 FIRST VIEWPORT: Big three-cell CPU flaps top left with load and pressure flaps right, a segmented lamp meter of the last three minutes whose hot rows keep amber and red lenses, then eight ranked sensor rows and a footer with update time and Quit.
 FORM: Split-flap concourse board, challenger chosen by the owner over assigned #4 (liquid-crystal strip); seed key 7dbf3ed9.
 FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, and DESIGN.md
 */
import SwiftUI

enum Format {
    static func degrees(_ celsius: Double) -> String {
        "\(Int(celsius.rounded()))°"
    }

    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    static func clock(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }
}

struct PopoverView: View {
    let monitor: Monitor

    static let boardRows = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            LampMeter(history: monitor.history)
            SensorBoard(sensors: Array(monitor.sensors.prefix(Self.boardRows)))
            footer
        }
        .padding(14)
        .frame(width: 324)
        .background(Board.steelFrame)
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                ColumnLabel("CPU DIE")
                FlapText(
                    text: monitor.cpuTemperature.map(Format.degrees) ?? "--°",
                    cells: 3,
                    size: .hero,
                    ink: monitor.cpuTemperature.map { Board.heroInk(for: HeatBand(celsius: $0)) } ?? Board.steelLight,
                    alignment: .trailing
                )
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 9) {
                stat("LOAD", value: monitor.cpuLoad.map(Format.percent) ?? "--", cells: 4, ink: Board.letterWhite)
                stat("PRESSURE", value: monitor.thermalState.boardTitle, cells: 8, ink: monitor.thermalState.ink)
            }
        }
    }

    private func stat(_ label: String, value: String, cells: Int, ink: Color) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            ColumnLabel(label)
            FlapText(text: value, cells: cells, ink: ink, alignment: .trailing)
        }
    }

    private var footer: some View {
        HStack(alignment: .center) {
            ColumnLabel("UPDATED")
            FlapText(text: Format.clock(monitor.updatedAt), cells: 5, ink: Board.steelLight)
            Spacer()
            QuitButton()
        }
    }
}

private struct ColumnLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Board.labelFont(11))
            .tracking(1.6)
            .foregroundStyle(Board.steelLight)
    }
}

private struct BoardPanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Board.flapBlack, in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Board.steelMid.opacity(0.45), lineWidth: 1))
    }
}

/// Three minutes of CPU temperature as a bank of lamps: columns are time, rows a fixed scale, each row's lens tinted by its band.
struct LampMeter: View {
    let history: [TemperatureSample]

    static let columns = 30
    static let rowFloors: [Double] = [30, 40, 50, 60, 70, 80, 90, 100]

    var body: some View {
        BoardPanel {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    ColumnLabel("LAST 3 MIN")
                    Spacer()
                    if let range {
                        Text(range)
                            .font(Board.labelFont(12))
                            .tracking(1.2)
                            .foregroundStyle(Board.letterWhite)
                            .monospacedDigit()
                    }
                }
                ZStack {
                    lamps
                    if history.count < 2 {
                        Text("COLLECTING READINGS")
                            .font(Board.labelFont(11))
                            .tracking(1.6)
                            .foregroundStyle(Board.steelLight)
                            .padding(.horizontal, 6)
                            .background(Board.flapBlack)
                    }
                }
                .frame(height: 46)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("CPU temperature over the last three minutes\(range.map { ", \($0)" } ?? "")")
    }

    private var lamps: some View {
        let columns = Self.columnPeaks(history)
        return Canvas { context, size in
            let gap: CGFloat = 1.5
            let cellWidth = (size.width - gap * CGFloat(Self.columns - 1)) / CGFloat(Self.columns)
            let cellHeight = (size.height - gap * CGFloat(Self.rowFloors.count - 1)) / CGFloat(Self.rowFloors.count)
            for column in 0..<Self.columns {
                let peak = columns[column]
                for (row, floor) in Self.rowFloors.enumerated() {
                    let band = HeatBand(celsius: floor)
                    let lit = peak.map { $0 >= floor } ?? false
                    let rect = CGRect(
                        x: CGFloat(column) * (cellWidth + gap),
                        y: size.height - CGFloat(row + 1) * cellHeight - CGFloat(row) * gap,
                        width: cellWidth,
                        height: cellHeight
                    )
                    let lens = lit ? Board.ink(for: band) : (band >= .hot ? Board.ink(for: band).opacity(0.16) : Board.lens)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(lens))
                }
            }
        }
    }

    /// Peak reading per column, newest column last; empty columns are nil.
    static func columnPeaks(_ history: [TemperatureSample]) -> [Double?] {
        let perColumn = max(1, Monitor.historyLength / columns)
        var peaks = [Double?](repeating: nil, count: columns)
        let recent = history.suffix(perColumn * columns)
        let offset = perColumn * columns - recent.count
        for (index, sample) in recent.enumerated() {
            let column = (offset + index) / perColumn
            peaks[column] = max(peaks[column] ?? -.infinity, sample.celsius)
        }
        return peaks
    }

    private var range: String? {
        guard let low = history.map(\.celsius).min(), let high = history.map(\.celsius).max() else { return nil }
        return "\(Int(low.rounded()))–\(Format.degrees(high))"
    }
}

private struct SensorBoard: View {
    let sensors: [SensorReading]

    static let nameCells = 12

    var body: some View {
        BoardPanel {
            Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 3) {
                GridRow {
                    Color.clear.frame(width: 6, height: 1)
                    ColumnLabel("SENSOR")
                    ColumnLabel("°C").gridColumnAlignment(.trailing)
                    ColumnLabel("STATUS")
                }
                if sensors.isEmpty {
                    GridRow {
                        Lamp(lit: false, color: Board.steelLight)
                        FlapText(text: "UNAVAILABLE", cells: Self.nameCells, ink: Board.steelLight)
                        FlapText(text: "--", cells: 3, ink: Board.steelLight, alignment: .trailing)
                        FlapText(text: "", cells: 4)
                    }
                } else {
                    ForEach(sensors) { sensor in
                        let band = HeatBand(celsius: sensor.celsius)
                        GridRow {
                            Lamp(lit: band >= .hot, color: Board.ink(for: band))
                            FlapText(text: sensor.name, cells: Self.nameCells, ink: band == .burn ? Board.burnRed : Board.steelLight)
                            FlapText(text: "\(Int(sensor.celsius.rounded()))", cells: 3, ink: Board.ink(for: band), alignment: .trailing)
                            FlapText(text: band.title, cells: 4, ink: Board.ink(for: band))
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(sensor.name), \(Format.degrees(sensor.celsius)), \(band.title.lowercased())")
                    }
                }
            }
        }
    }
}

/// A flap-strip button with a separate key-equivalent segment; lights amber on hover or press.
private struct QuitButton: View {
    @State private var hovering = false

    var body: some View {
        Button { NSApplication.shared.terminate(nil) } label: {
            HStack(spacing: 3) {
                FlapText(text: "QUIT", cells: 4, ink: hovering ? Board.amber : Board.letterWhite)
                HStack(spacing: 1) {
                    Image(systemName: "command").font(.system(size: 9, weight: .semibold))
                    Text("Q").font(Board.flapFont(15))
                }
                .foregroundStyle(hovering ? Board.amber : Board.steelLight)
                .frame(width: 26, height: FlapSize.row.height)
                .background(Board.flapTop, in: RoundedRectangle(cornerRadius: 1.5))
                .padding(FlapSize.row.spacing)
                .background(Board.flapBlack, in: RoundedRectangle(cornerRadius: 2.5))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut("q")
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .accessibilityLabel("Quit Thermals")
    }
}

extension ProcessInfo.ThermalState {
    var boardTitle: String {
        switch self {
        case .nominal: "NOMINAL"
        case .fair: "FAIR"
        case .serious: "SERIOUS"
        case .critical: "CRITICAL"
        @unknown default: "UNKNOWN"
        }
    }

    var ink: Color {
        switch self {
        case .nominal: Board.steelLight
        case .fair: Board.letterWhite
        case .serious: Board.amber
        case .critical: Board.burnRed
        @unknown default: Board.steelLight
        }
    }
}
