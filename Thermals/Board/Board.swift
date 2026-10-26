import SwiftUI

enum Board {
    static let popoverWidth: CGFloat = 400
    static let flapBlack = Color(red: 0x0B / 255, green: 0x0B / 255, blue: 0x0D / 255)
    static let flapTop = Color(red: 0x24 / 255, green: 0x25 / 255, blue: 0x29 / 255)
    static let flapBottom = Color(red: 0x1B / 255, green: 0x1C / 255, blue: 0x1F / 255)
    static let lens = Color(red: 0x1E / 255, green: 0x1F / 255, blue: 0x23 / 255)
    static let steelFrame = Color(red: 0x2A / 255, green: 0x2D / 255, blue: 0x31 / 255)
    static let steelMid = Color(red: 0x5B / 255, green: 0x5E / 255, blue: 0x63 / 255)
    static let steelLight = Color(red: 0xA7 / 255, green: 0xAA / 255, blue: 0xAF / 255)
    static let letterWhite = Color(red: 0xF2 / 255, green: 0xF2 / 255, blue: 0xF2 / 255)
    static let amber = color(amberRGB)
    static let burnRed = color(burnRedRGB)
    private static let amberRGB: (Double, Double, Double) = (0xFF, 0xB0, 0x00)
    private static let burnRedRGB: (Double, Double, Double) = (0xE5, 0x38, 0x3B)

    static func flapFont(_ size: CGFloat) -> Font { .custom("BarlowCondensed-SemiBold", size: size) }
    static func labelFont(_ size: CGFloat) -> Font { .custom("BarlowCondensed-Medium", size: size) }

    /// Settle for rows moving to a new rank: fast start, long exponential tail.
    static let settle = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.5)

    /// The one heat gradient: steel blue (cool) → white (warm) → amber (hot) → red (burn), used by every heat-colored
    /// element and the menu bar. Stop positions match `HeatLevel`'s band edges; the light-scheme ramp keeps contrast on a light menu bar.
    static func heat(_ level: HeatLevel, scheme: ColorScheme = .dark) -> Color {
        let stops = scheme == .light ? lightHeatStops : darkHeatStops
        let t = level.position
        guard let upper = stops.firstIndex(where: { $0.position >= t }) else { return color(stops[stops.count - 1].rgb) }
        guard upper > 0 else { return color(stops[0].rgb) }
        let (low, high) = (stops[upper - 1], stops[upper])
        let f = (t - low.position) / (high.position - low.position)
        return color((
            low.rgb.0 + (high.rgb.0 - low.rgb.0) * f,
            low.rgb.1 + (high.rgb.1 - low.rgb.1) * f,
            low.rgb.2 + (high.rgb.2 - low.rgb.2) * f
        ))
    }

    typealias HeatStop = (position: Double, rgb: (Double, Double, Double))

    static let darkHeatStops: [HeatStop] = [
        (0, (0x6F, 0x9C, 0xC8)),
        (HeatLevel.warmStart, (0xDC, 0xE6, 0xEE)),
        (0.55, (0xFF, 0xE3, 0xA3)),
        (HeatLevel.hotStart, amberRGB),
        (HeatLevel.burnStart, (0xF2, 0x5A, 0x2D)),
        (1, burnRedRGB),
    ]

    static let lightHeatStops: [HeatStop] = [
        (0, (0x2E, 0x62, 0x99)),
        (HeatLevel.warmStart, (0x4A, 0x55, 0x60)),
        (0.55, (0x8A, 0x64, 0x00)),
        (HeatLevel.hotStart, (0xA0, 0x4A, 0x00)),
        (HeatLevel.burnStart, (0xB8, 0x36, 0x0F)),
        (1, (0xB3, 0x14, 0x1A)),
    ]

    private static func color(_ rgb: (Double, Double, Double)) -> Color {
        Color(red: rgb.0 / 255, green: rgb.1 / 255, blue: rgb.2 / 255)
    }
}

struct FlapSize {
    let width: CGFloat
    let height: CGFloat
    let fontSize: CGFloat
    let spacing: CGFloat

    static let hero = FlapSize(width: 38, height: 58, fontSize: 50, spacing: 3)
    static let row = FlapSize(width: 11.5, height: 19, fontSize: 15, spacing: 1.5)

    var isLarge: Bool { height > 30 }

    /// Outer size of a housed `FlapText` strip.
    func stripWidth(cells: Int) -> CGFloat { CGFloat(cells) * width + CGFloat(cells + 1) * spacing }
    var stripHeight: CGFloat { height + 2 * spacing }
}

/// A housed strip of split-flap cells; pads with blanks or truncates to `cells`, and flips cell by cell when the text changes.
struct FlapText: View {
    let text: String
    let cells: Int
    var size: FlapSize = .row
    var ink: Color = Board.letterWhite
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        HStack(spacing: size.spacing) {
            ForEach(Array(characters.enumerated()), id: \.offset) { index, character in
                FlapCell(character: character, size: size, ink: ink, cascadeIndex: index)
            }
        }
        .padding(size.spacing)
        .background(Board.flapBlack, in: RoundedRectangle(cornerRadius: size.isLarge ? 5 : 2.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    private var characters: [Character] {
        let clipped = Array(text.uppercased().prefix(cells))
        let padding = Array(repeating: Character(" "), count: cells - clipped.count)
        return alignment == .trailing ? padding + clipped : clipped + padding
    }
}

struct FlapCell: View {
    let character: Character
    let size: FlapSize
    let ink: Color
    let cascadeIndex: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Character?
    @State private var previous: Character = " "
    @State private var fallingAngle: Double = 0
    @State private var risingAngle: Double = 0
    @State private var flipping = false

    var body: some View {
        let current = shown ?? character
        VStack(spacing: 0) {
            ZStack {
                half(current, top: true)
                if flipping {
                    half(previous, top: true)
                        .rotation3DEffect(.degrees(fallingAngle), axis: (1, 0, 0), anchor: .bottom, perspective: 0.6)
                }
            }
            ZStack {
                half(flipping ? previous : current, top: false)
                if flipping {
                    half(current, top: false)
                        .rotation3DEffect(.degrees(risingAngle), axis: (1, 0, 0), anchor: .top, perspective: 0.6)
                }
            }
        }
        .overlay(hinge)
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: size.isLarge ? 3 : 1.5))
        .overlay(axlePins)
        .onAppear { shown = character }
        .onChange(of: character) { old, new in flip(from: shown ?? old, to: new) }
    }

    private func flip(from old: Character, to new: Character) {
        guard !reduceMotion else { shown = new; return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(28 * cascadeIndex))
            previous = old
            shown = new
            fallingAngle = 0
            risingAngle = 90
            flipping = true
            withAnimation(.easeIn(duration: 0.08)) { fallingAngle = -90 } completion: {
                withAnimation(.easeOut(duration: 0.1)) { risingAngle = 0 } completion: { flipping = false }
            }
        }
    }

    private func half(_ character: Character, top: Bool) -> some View {
        Text(String(character))
            .font(Board.flapFont(size.fontSize))
            .foregroundStyle(ink)
            .frame(width: size.width, height: size.height)
            .frame(height: size.height / 2, alignment: top ? .top : .bottom)
            .clipped()
            .background(
                LinearGradient(
                    colors: top ? [Board.flapTop, Board.flapTop.opacity(0.92)] : [Board.flapBottom, Board.flapTop.opacity(0.85)],
                    startPoint: .top, endPoint: .bottom
                )
            )
    }

    private var hinge: some View {
        Rectangle()
            .fill(Board.flapBlack.opacity(size.isLarge ? 1 : 0.55))
            .frame(height: size.isLarge ? 2 : 0.5)
    }

    @ViewBuilder private var axlePins: some View {
        if size.isLarge {
            HStack {
                pin
                Spacer()
                pin
            }
            .frame(width: size.width + 4)
        }
    }

    private var pin: some View {
        RoundedRectangle(cornerRadius: 0.75)
            .fill(Board.steelMid)
            .frame(width: 2.5, height: 6)
    }
}

/// An unlit lamp is a dark lens; lit, it glows in its band color.
struct Lamp: View {
    let lit: Bool
    let color: Color

    var body: some View {
        Circle()
            .fill(lit ? color : Board.lens)
            .shadow(color: lit ? color.opacity(0.7) : .clear, radius: 3, y: 0.5)
            .frame(width: 6, height: 6)
    }
}
