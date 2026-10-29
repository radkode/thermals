import SwiftUI

struct SessionReceiptView: View {
    let monitor: Monitor
    @State var expanded = false
    @Environment(\.temperatureUnit) private var unit
    @State private var copied = false

    var body: some View {
        BoardPanel {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ColumnLabel(monitor.sessions.current == nil ? "WORK SESSION" : "RECORDING")
                    Spacer(minLength: 0)
                    if let session = monitor.sessions.current {
                        ColumnLabel(Format.duration(session.duration))
                        FlapButton(title: "STOP", accessibilityName: "Stop recording this session", action: monitor.stopSession)
                    } else {
                        FlapButton(title: "START", accessibilityName: "Start a thermal session for a build or render", action: monitor.startSession)
                    }
                }
                if let receipt = monitor.sessions.last, monitor.sessions.current == nil {
                    DisclosureGroup(isExpanded: $expanded) {
                        BoardNote(receipt.receipt(unit: unit)).textSelection(.enabled)
                        HStack {
                            BoardNote("Copies measurements only, without process names.")
                            Spacer(minLength: 0)
                            FlapButton(title: copied ? "COPIED" : "COPY", accessibilityName: "Copy the session receipt") {
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                copied = pasteboard.setString(receipt.receipt(unit: unit), forType: .string)
                            }
                        }
                    } label: {
                        HStack {
                            ColumnLabel("LAST SESSION")
                            Spacer()
                            FlapText(text: receipt.peak.map { Format.degrees($0, unit: unit) } ?? "--", cells: 4, alignment: .trailing)
                        }
                    }
                    .tint(Board.steelLight)
                }
            }
        }
        .help("Start before a build or render and stop afterward for a local receipt. Measures the whole Mac and retains the latest completed session. Missing intervals are not estimated.")
        .onChange(of: monitor.sessions.last) { _, _ in copied = false }
    }
}
