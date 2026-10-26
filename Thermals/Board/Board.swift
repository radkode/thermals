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
    static let amber = Color(red: 0xFF / 255, green: 0xB0 / 255, blue: 0x00 / 255)
    static let burnRed = Color(red: 0xE5 / 255, green: 0x38 / 255, blue: 0x3B / 255)
    static let deepAmber = Color(red: 0xA0 / 255, green: 0x4A / 255, blue: 0x00 / 255)
    static let deepRed = Color(red: 0xB3 / 255, green: 0x14 / 255, blue: 0x1A / 255)

    static func flapFont(_ size: CGFloat) -> Font { .custom("BarlowCondensed-SemiBold", size: size) }
    static func labelFont(_ size: CGFloat) -> Font { .custom("BarlowCondensed-Medium", size: size) }

    /// Settle for rows moving to a new rank: fast start, long exponential tail.
    static let settle = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.5)

    static func ink(for band: HeatBand) -> Color {
        switch band {
        case .cool: steelLight
        case .warm: letterWhite
        case .hot: amber
        case .burn: burnRed
        }
    }

    /// The headline never reads dimmer than letter white.
    static func heroInk(for band: HeatBand) -> Color {
        band >= .hot ? ink(for: band) : letterWhite
    }

    /// Menu bar tint, deepened on a light menu bar to keep contrast.
    static func menuBarInk(for band: HeatBand, scheme: ColorScheme) -> Color {
        switch (band >= .burn, scheme) {
        case (true, .light): deepRed
        case (true, _): burnRed
        case (false, .light): deepAmber
        case (false, _): amber
        }
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
