import Charts
import SwiftUI

enum Format {
    static func degrees(_ celsius: Double) -> String {
        "\(Int(celsius.rounded()))°"
    }

    static func percent(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)))
    }
}

struct PopoverView: View {
    let monitor: Monitor

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            TemperatureChart(history: monitor.history)
            Divider()
            details
            Divider()
            SensorList(sensors: monitor.sensors)
            Divider()
            HStack {
                Spacer()
                Button("Quit Thermals") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("CPU")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(monitor.cpuTemperature.map { "\(Format.degrees($0))C" } ?? "--")
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.default, value: monitor.cpuTemperature)
            }
            Spacer()
            ThermalStateLabel(state: monitor.thermalState)
        }
    }

    private var details: some View {
        Grid(alignment: .leading, verticalSpacing: 6) {
            GridRow {
                Text("Load").foregroundStyle(.secondary)
                Text(monitor.cpuLoad.map(Format.percent) ?? "--")
                    .monospacedDigit()
                    .gridColumnAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            GridRow {
                Text("Thermal pressure").foregroundStyle(.secondary)
                Text(monitor.thermalState.title)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .font(.callout)
    }
}

private struct ThermalStateLabel: View {
    let state: ProcessInfo.ThermalState

    var body: some View {
        Label(state.title, systemImage: state.symbol)
            .font(.callout.weight(.medium))
            .foregroundStyle(state.color)
            .help("macOS thermal pressure")
    }
}

private struct TemperatureChart: View {
    let history: [TemperatureSample]

    var body: some View {
        Group {
            if history.count < 2 {
                Text("Collecting readings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart(history) { sample in
                    LineMark(x: .value("Time", sample.date), y: .value("Celsius", sample.celsius))
                        .interpolationMethod(.monotone)
                }
                .chartXAxis(.hidden)
                .chartYScale(domain: yDomain)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine()
                        AxisValueLabel { if let c = value.as(Double.self) { Text(Format.degrees(c)) } }
                    }
                }
            }
        }
        .frame(height: 76)
        .accessibilityLabel("CPU temperature over the last three minutes")
    }

    private var yDomain: ClosedRange<Double> {
        let values = history.map(\.celsius)
        let low = (values.min() ?? 0) - 3
        let high = (values.max() ?? 0) + 3
        return low...high
    }
}

private struct SensorList: View {
    let sensors: [SensorReading]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sensors")
                .font(.headline)
            if sensors.isEmpty {
                Text("Temperature sensors aren't available on this Mac.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    Grid(alignment: .leading, verticalSpacing: 4) {
                        ForEach(sensors) { sensor in
                            GridRow {
                                Text(sensor.name)
                                    .lineLimit(1)
                                    .foregroundStyle(.secondary)
                                Text(Format.degrees(sensor.celsius))
                                    .monospacedDigit()
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                    .font(.callout)
                }
                .frame(maxHeight: 160)
            }
        }
    }
}

private extension ProcessInfo.ThermalState {
    var title: String {
        switch self {
        case .nominal: "Nominal"
        case .fair: "Fair"
        case .serious: "Serious"
        case .critical: "Critical"
        @unknown default: "Unknown"
        }
    }

    var symbol: String {
        switch self {
        case .nominal: "checkmark.circle"
        case .fair: "thermometer.medium"
        case .serious, .critical: "exclamationmark.triangle.fill"
        @unknown default: "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .nominal: .secondary
        case .fair: .yellow
        case .serious: .orange
        case .critical: .red
        @unknown default: .secondary
        }
    }
}
