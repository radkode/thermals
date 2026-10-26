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

/// Row scale for a lamp meter: fitted to the window's readings, never narrower than `minimumSpan`, kept inside `bounds`.
struct MeterScale {
    let rows: Int
    let minimumSpan: Double
    let bounds: ClosedRange<Double>

    static let temperature = MeterScale(rows: 8, minimumSpan: 10, bounds: 20...110)
    static let load = MeterScale(rows: 8, minimumSpan: 20, bounds: 0...100)

    /// Evenly spaced row floors, lowest first; the bottom row sits at the window's low and the top at its high.
    func floors(for values: [Double]) -> [Double] {
        let low = values.min() ?? bounds.lowerBound
        let high = values.max() ?? bounds.upperBound
        let span = min(max(high - low, minimumSpan), bounds.upperBound - bounds.lowerBound)
        let start = min(max((low + high) / 2 - span / 2, bounds.lowerBound), bounds.upperBound - span)
        let fitted = high - low >= minimumSpan ? low : start
        return (0..<rows).map { fitted + span * Double($0) / Double(max(rows - 1, 1)) }
    }
}

/// Three minutes of readings as a bank of lamps: columns are time, rows a scale fitted to the window, each lens tinted from the heat gradient at its row's value.
struct LampMeter: View {
    let values: [Double]
    let scale: MeterScale
    let level: (Double) -> HeatLevel
    let unit: String
    let accessibilityName: String

    static let columns = 30
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
        let rows = scale.floors(for: values).map { (floor: $0, level: level($0)) }
        return Canvas { context, size in
            let gap: CGFloat = 1.5
            let cellWidth = (size.width - gap * CGFloat(Self.columns - 1)) / CGFloat(Self.columns)
            let cellHeight = (size.height - gap * CGFloat(rows.count - 1)) / CGFloat(rows.count)
            for column in 0..<Self.columns {
                let peak = columns[column]
                for (index, row) in rows.enumerated() {
                    let lit = peak.map { $0 >= row.floor - 1e-9 } ?? false
                    let rect = CGRect(
                        x: CGFloat(column) * (cellWidth + gap),
                        y: size.height - CGFloat(index + 1) * cellHeight - CGFloat(index) * gap,
                        width: cellWidth,
                        height: cellHeight
                    )
                    let lens = lit ? Board.heat(row.level) : (row.level.band >= .hot ? Board.heat(row.level).opacity(0.16) : Board.lens)
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

protocol FlapTabOption: CaseIterable, Hashable where AllCases: RandomAccessCollection {
    var title: String { get }
}

enum BoardKind: String, FlapTabOption {
    case heat, cpu

    var title: String {
        switch self {
        case .heat: "HEAT"
        case .cpu: "CPU"
        }
    }
}

/// What the menu bar item shows.
enum MenuBarItem: String, FlapTabOption {
    case temperature, load, both

    var title: String {
        switch self {
        case .temperature: "TEMP"
        case .load: "LOAD"
        case .both: "BOTH"
        }
    }
}

/// Flap-strip tabs; the selected option's lamp is lit. With `shortcuts`, ⌘1, ⌘2… select in order.
struct FlapTabs<Option: FlapTabOption>: View {
    @Binding var selection: Option
    var shortcuts = false
    let noun: String

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(Option.allCases.enumerated()), id: \.element) { index, option in
                let selected = option == selection
                let button = Button { selection = option } label: {
                    HStack(spacing: 5) {
                        Lamp(lit: selected, color: Board.amber)
                        FlapText(text: option.title, cells: 4, ink: selected ? Board.letterWhite : Board.steelLight)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(option.title.capitalized) \(noun)")
                .accessibilityAddTraits(selected ? .isSelected : [])

                if shortcuts {
                    button.keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                } else {
                    button
                }
            }
        }
    }
}
