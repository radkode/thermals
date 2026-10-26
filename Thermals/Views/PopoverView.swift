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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            BoardSwitcher(selection: Binding(get: { pinnedBoard ?? storedBoard }, set: { storedBoard = $0 }))
            switch pinnedBoard ?? storedBoard {
            case .heat: HeatBoard(monitor: monitor)
            case .cpu: CPUBoard(monitor: monitor)
            }
            footer
        }
        .padding(14)
        .frame(width: 324)
        .background(Board.steelFrame)
        .environment(\.colorScheme, .dark)
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
