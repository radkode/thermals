/*
 THESIS: A rail concourse departure board where sensors and cores are departures in fixed order, lit by heat; refuses the stock stats popover of gauges, rings and system-gray rows.
 OWN-WORLD: Matte flap cells with a hinge gap and axle pins in black housings on a steel frame; Barlow Condensed caps; steel light for cool, letter white for warm, amber lamps for hot, red type for burn.
 STORY: HEAT: the big flaps say how hot the CPU is, the lamps and amber or red rows say which sensors drive it. CPU: the big flaps say how loaded it is with the die temperature beside it, the core platforms say where the load sits, your processes say who is causing it.
 FIRST VIEWPORT: HEAT / CPU flap tabs, then the selected board: hero flaps with two stats right, a three-minute lamp meter, the board panels, and a footer with update time and Quit.
 FORM: Split-flap concourse board, challenger chosen by the owner over assigned #4 (liquid-crystal strip); seed key 7dbf3ed9. CPU board structure: core departures, challenger chosen over assigned #7 (signal box panel); seed key a97472d0.
 FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, and DESIGN.md
 */
import SwiftUI

struct PopoverView: View {
    let monitor: Monitor
    /// Pins the board for snapshots; the live popover uses the stored choice.
    var pinnedBoard: BoardKind?

    @AppStorage("board") private var storedBoard = BoardKind.heat
    @AppStorage("menuBarItem") private var menuBarItem = MenuBarItem.temperature

    private var board: BoardKind { pinnedBoard ?? storedBoard }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FlapTabs(selection: Binding(get: { board }, set: { storedBoard = $0 }), shortcuts: true, noun: "board")
            // Both boards stay laid out so the popover keeps the taller one's height and Quit never moves on switch.
            ZStack(alignment: .topLeading) {
                ForEach(BoardKind.allCases, id: \.self) { kind in
                    let shown = kind == board
                    Group {
                        switch kind {
                        case .heat: HeatBoard(monitor: monitor)
                        case .cpu: CPUBoard(monitor: monitor)
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .opacity(shown ? 1 : 0)
                    .allowsHitTesting(shown)
                    .accessibilityHidden(!shown)
                }
            }
            HStack {
                ColumnLabel("MENU BAR")
                Spacer()
                FlapTabs(selection: $menuBarItem, noun: "in menu bar")
            }
            HStack {
                ColumnLabel("UPDATE EVERY")
                Spacer()
                FlapTabs(selection: Binding(get: { monitor.rate }, set: { monitor.rate = $0 }), noun: "update interval")
            }
            footer
        }
        .padding(14)
        .frame(width: Board.popoverWidth)
        .background(Board.steelFrame)
        .environment(\.colorScheme, .dark)
        .onAppear { monitor.samplesProcesses = board == .cpu }
        .onChange(of: board) { _, new in monitor.samplesProcesses = new == .cpu }
        .onDisappear { monitor.samplesProcesses = false }
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
