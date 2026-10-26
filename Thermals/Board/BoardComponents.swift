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

struct ColumnLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Board.labelFont(11))
            .tracking(1.6)
            .foregroundStyle(Board.steelLight)
    }
}

struct BoardPanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Board.flapBlack, in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Board.steelMid.opacity(0.45), lineWidth: 1))
    }
}

/// A flap-strip button with a separate key-equivalent segment; lights amber on hover or press.
struct QuitButton: View {
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

extension EnvironmentValues {
    /// Set by offscreen renders, where scroll views draw blank.
    @Entry var snapshotRendering = false
}

/// A labelled flap strip, right-aligned, for header stats.
struct BoardStat: View {
    let label: String
    let value: String
    let cells: Int
    let ink: Color

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            ColumnLabel(label)
            FlapText(text: value, cells: cells, ink: ink, alignment: .trailing)
        }
    }
}

/// Three minutes of readings as a bank of lamps: columns are time, rows a fixed scale, each row's lens tinted by its band.
struct LampMeter: View {
    let values: [Double]
    let rowFloors: [Double]
    let band: (Double) -> HeatBand
    let unit: String
    let accessibilityName: String

    static let columns = 30
    static let temperatureRows: [Double] = [30, 40, 50, 60, 70, 80, 90, 100]
    static let loadRows: [Double] = [1, 12.5, 25, 37.5, 50, 62.5, 75, 87.5]

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
                    if values.count < 2 {
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
        .accessibilityLabel("\(accessibilityName) over the last three minutes\(range.map { ", \($0)" } ?? "")")
    }

    private var lamps: some View {
        let columns = Self.columnPeaks(values)
        let rows = rowFloors.map { (floor: $0, band: band($0)) }
        return Canvas { context, size in
            let gap: CGFloat = 1.5
            let cellWidth = (size.width - gap * CGFloat(Self.columns - 1)) / CGFloat(Self.columns)
            let cellHeight = (size.height - gap * CGFloat(rows.count - 1)) / CGFloat(rows.count)
            for column in 0..<Self.columns {
                let peak = columns[column]
                for (index, row) in rows.enumerated() {
                    let lit = peak.map { $0 >= row.floor } ?? false
                    let rect = CGRect(
                        x: CGFloat(column) * (cellWidth + gap),
                        y: size.height - CGFloat(index + 1) * cellHeight - CGFloat(index) * gap,
                        width: cellWidth,
                        height: cellHeight
                    )
                    let lens = lit ? Board.ink(for: row.band) : (row.band >= .hot ? Board.ink(for: row.band).opacity(0.16) : Board.lens)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(lens))
                }
            }
        }
    }

    /// Peak reading per column, newest column last; empty columns are nil.
    static func columnPeaks(_ values: [Double]) -> [Double?] {
        let perColumn = max(1, Monitor.historyLength / columns)
        var peaks = [Double?](repeating: nil, count: columns)
        let recent = values.suffix(perColumn * columns)
        let offset = perColumn * columns - recent.count
        for (index, value) in recent.enumerated() {
            let column = (offset + index) / perColumn
            peaks[column] = max(peaks[column] ?? -.infinity, value)
        }
        return peaks
    }

    private var range: String? {
        guard let low = values.min(), let high = values.max() else { return nil }
        return "\(Int(low.rounded()))–\(Int(high.rounded()))\(unit)"
    }
}

enum BoardKind: String, CaseIterable {
    case heat, cpu

    var title: String {
        switch self {
        case .heat: "HEAT"
        case .cpu: "CPU"
        }
    }
}

/// Flap-strip tabs; the selected board's lamp is lit. ⌘1 and ⌘2 switch boards.
struct BoardSwitcher: View {
    @Binding var selection: BoardKind

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(BoardKind.allCases.enumerated()), id: \.element) { index, kind in
                let selected = kind == selection
                Button { selection = kind } label: {
                    HStack(spacing: 5) {
                        Lamp(lit: selected, color: Board.amber)
                        FlapText(text: kind.title, cells: 4, ink: selected ? Board.letterWhite : Board.steelLight)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                .accessibilityLabel("\(kind.title.capitalized) board")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}
