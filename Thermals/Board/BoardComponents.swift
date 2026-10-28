import SwiftUI

enum Format {
    static func degrees(_ celsius: Double, unit: TemperatureUnit = .celsius) -> String {
        "\(Int(unit.value(celsius).rounded()))°"
    }

    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    static func watts(_ watts: Double) -> String {
        "\(Int(watts.rounded()))W"
    }

    /// Binary gigabytes, as Activity Monitor counts them: one decimal under 100.
    static func gigabytes(_ bytes: UInt64) -> String {
        let value = Double(bytes) / 1_073_741_824
        return value < 99.95 ? String(format: "%.1f", value) : "\(Int(value.rounded()))"
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

struct BoardNote: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(Board.labelFont(14))
            .foregroundStyle(Board.steelLight)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct ReadingNotice: View {
    let state: ReadingState
    let source: String
    var empty = false
    var retry: (() -> Void)?
    @Environment(\.readingDate) private var now
    @Environment(\.sampleInterval) private var interval

    var body: some View {
        if let message {
            VStack(alignment: .leading, spacing: 6) {
                BoardNote(message)
                if let retry, state != .loading {
                    FlapButton(title: "RETRY", accessibilityName: "Retry \(source) reading", action: retry)
                }
            }
        }
    }

    private var message: String? {
        if state.isStale(at: now, interval: interval) { return "\(source): stale. Waiting for a fresh sample." }
        switch state {
        case .loading: return "\(source): collecting readings…"
        case .unavailable: return "\(source) unavailable. Support varies by Mac and macOS version. Restart Thermals if this worked before."
        case .failed: return "\(source) could not be read. Retrying automatically."
        case .available: return empty ? "No active \(source.lowercased()) in this sample." : nil
        }
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

/// A flap strip that acts. Hover inks it amber, like Quit.
struct FlapButton: View {
    let title: String
    let accessibilityName: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            FlapText(text: title, cells: title.count, ink: hovering ? Board.amber : Board.letterWhite)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .accessibilityLabel(accessibilityName)
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

extension MemoryPressure {
    var boardTitle: String {
        switch self {
        case .normal: "NORMAL"
        case .warn: "WARN"
        case .critical: "CRITICAL"
        }
    }

    var ink: Color {
        switch self {
        case .normal: Board.steelLight
        case .warn: Board.amber
        case .critical: Board.burnRed
        }
    }
}

extension EnvironmentValues {
    /// Set by offscreen renders, where scroll views draw blank.
    @Entry var snapshotRendering = false
    @Entry var temperatureUnit = TemperatureUnit.celsius
    @Entry var readingDate = Date.now
    @Entry var sampleInterval: TimeInterval = 6
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
        .help("\(label): \(value)")
    }
}

/// Row scale for a lamp meter: fitted to the window's readings, never narrower than `minimumSpan`, kept inside `bounds`.
struct MeterScale {
    let rows: Int
    let minimumSpan: Double
    let bounds: ClosedRange<Double>

    static let temperature = MeterScale(rows: 8, minimumSpan: 10, bounds: 20...110)
    static let load = MeterScale(rows: 8, minimumSpan: 20, bounds: 0...100)
    static let memory = MeterScale(rows: 8, minimumSpan: 10, bounds: 0...100)

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
    @Environment(\.readingDate) private var now
    let readings: [TimedValue]
    let scale: MeterScale
    let level: (Double) -> HeatLevel
    let unit: String
    let accessibilityName: String
    var state: ReadingState = .loading
    var utilization = false
    /// Converts a reading for the range readout only; rows and colors use the reading as measured.
    var display: (Double) -> Double = { $0 }

    static let columns = 30
    static let loadRows: [Double] = [1, 12.5, 25, 37.5, 50, 62.5, 75, 87.5]

    private var recent: [TimedValue] { readings.filter { (0...Monitor.historyWindow).contains(now.timeIntervalSince($0.date)) } }
    private var values: [Double] { recent.map(\.value) }

    var body: some View {
        BoardPanel {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    ColumnLabel("LAST 3 MIN · NOW →")
                    Spacer()
                    if let range {
                        Text("MIN/MAX " + range)
                            .font(Board.labelFont(12))
                            .tracking(1.2)
                            .foregroundStyle(Board.letterWhite)
                            .monospacedDigit()
                    }
                }
                ZStack {
                    lamps
                    if values.count < 2 {
                        Text(state == .loading ? "COLLECTING READINGS" : values.isEmpty ? "NO RECENT READINGS" : "WAITING FOR NEXT READING")
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
        .accessibilityLabel("\(accessibilityName) over the last three minutes. \(Self.trend(recent)). Observed minimum and maximum \(range ?? "unavailable"). Newest readings on the right; gaps mean no recent measurement.")
        .help("Observed minimum and maximum are shown above. The chart scale adapts to the readings; gaps indicate missing measurements.")
    }

    private var lamps: some View {
        let columns = Self.columnPeaks(recent, now: now)
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
                    let color = utilization ? Board.usage(row.level) : Board.heat(row.level)
                    let lens = lit ? color : (!utilization && row.level.band >= .hot ? color.opacity(0.16) : Board.lens)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(lens))
                }
            }
        }
    }

    /// Short sampling gaps hold for at most two slices; sleep and failed-read gaps remain empty.
    static func columnPeaks(_ readings: [TimedValue], now: Date, window: TimeInterval = Monitor.historyWindow) -> [Double?] {
        var peaks = [Double?](repeating: nil, count: columns)
        let slice = window / Double(columns)
        for reading in readings {
            let age = now.timeIntervalSince(reading.date)
            guard age >= 0, age <= window else { continue }
            let column = columns - 1 - Int((age / slice).rounded())
            guard peaks.indices.contains(column) else { continue }
            peaks[column] = max(peaks[column] ?? -.infinity, reading.value)
        }
        var lastMeasured: Int?
        for column in peaks.indices {
            if peaks[column] != nil { lastMeasured = column }
            else if let lastMeasured, column - lastMeasured < 2 { peaks[column] = peaks[lastMeasured] }
        }
        return peaks
    }

    static func trend(_ readings: [TimedValue]) -> String {
        guard let first = readings.first, let last = readings.last, readings.count > 1 else { return "Not enough readings for a trend" }
        let change = last.value - first.value
        if abs(change) < 1 { return "Steady across the sampled period" }
        return change > 0 ? "Rising across the sampled period" : "Falling across the sampled period"
    }

    private var range: String? {
        guard let low = values.min(), let high = values.max() else { return nil }
        return "\(Int(display(low).rounded()))–\(Int(display(high).rounded()))\(unit)"
    }
}

/// A short row of lenses at the lamp meter's load floors, the first `lit` of them lit; `tint` colors each lens from its floor.
struct LensBar: View {
    let lit: Int
    let tint: (_ floor: Double, _ lit: Bool) -> Color

    /// Lit up to `percent`: every floor at or below it.
    init(percent: Double, tint: @escaping (_ floor: Double, _ lit: Bool) -> Color) {
        self.init(lit: LampMeter.loadRows.filter { percent >= $0 }.count, tint: tint)
    }

    init(lit: Int, tint: @escaping (_ floor: Double, _ lit: Bool) -> Color) {
        self.lit = lit
        self.tint = tint
    }

    var body: some View {
        Canvas { context, size in
            let floors = LampMeter.loadRows
            let gap: CGFloat = 1.5
            let width = (size.width - gap * CGFloat(floors.count - 1)) / CGFloat(floors.count)
            for (index, floor) in floors.enumerated() {
                let rect = CGRect(x: CGFloat(index) * (width + gap), y: 0, width: width, height: size.height)
                context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(tint(floor, index < lit)))
            }
        }
        .frame(height: 10)
        .frame(maxWidth: .infinity)
    }
}

protocol FlapTabOption: CaseIterable, Hashable where AllCases: RandomAccessCollection {
    var title: String { get }
}

enum BoardKind: String, FlapTabOption {
    case heat, cpu, ram

    var title: String {
        switch self {
        case .heat: "HEAT"
        case .cpu: "CPU"
        case .ram: "RAM"
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

/// How often readings refresh.
enum SampleRate: String, FlapTabOption {
    case three, six, ten

    var seconds: TimeInterval {
        switch self {
        case .three: 3
        case .six: 6
        case .ten: 10
        }
    }

    var title: String { "\(Int(seconds)) S" }
}

/// How temperatures are shown. Readings, bands and colors stay in Celsius; only the displayed number converts.
enum TemperatureUnit: String, FlapTabOption {
    case celsius, fahrenheit

    static var system: TemperatureUnit { Locale.current.measurementSystem == .us ? .fahrenheit : .celsius }

    var title: String {
        switch self {
        case .celsius: "°C"
        case .fahrenheit: "°F"
        }
    }

    func value(_ celsius: Double) -> Double {
        switch self {
        case .celsius: celsius
        case .fahrenheit: celsius * 9 / 5 + 32
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
