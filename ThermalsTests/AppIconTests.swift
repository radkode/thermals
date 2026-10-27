import AppKit
import SwiftUI
import Testing
@testable import Thermals

/// The app icon, drawn from the board's own materials. Opt in: `TEST_RUNNER_ICON_DIR=Thermals/Assets.xcassets/AppIcon.appiconset
/// xcodebuild ... test` rewrites every size in the asset catalog.
@MainActor
struct AppIconTests {
    nonisolated static let directory = ProcessInfo.processInfo.environment["ICON_DIR"]

    @Test(.enabled(if: directory != nil))
    func renderIcons() throws {
        for size in [16, 32, 64, 128, 256, 512, 1024] {
            let renderer = ImageRenderer(content: AppIcon())
            renderer.scale = CGFloat(size) / 1024
            let image = try #require(renderer.cgImage)
            let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: Self.directory!).appendingPathComponent("icon-\(size).png"))
        }
    }
}

/// The LAST 3 MIN lamp bank on the macOS icon grid: an 824pt continuous squircle in steel, centered on a 1024pt canvas.
struct AppIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 185.4, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.23), Board.steelFrame, Color(white: 0.12)], startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 185.4, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.14), .clear], startPoint: .top, endPoint: .center), lineWidth: 3)
                )
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.35), radius: 14, y: 10)
            LampBank()
        }
        .frame(width: 1024, height: 1024)
    }
}

/// The LAST 3 MIN lamp bank: columns climbing from cool to burn, each lens tinted by its row's heat.
private struct LampBank: View {
    static let columns = 7
    static let rows = 8
    static let heights = [2, 3, 3, 4, 5, 7, 8]

    var body: some View {
        Canvas { context, size in
            let gap: CGFloat = 16
            let width = (size.width - gap * CGFloat(Self.columns - 1)) / CGFloat(Self.columns)
            let height = (size.height - gap * CGFloat(Self.rows - 1)) / CGFloat(Self.rows)
            for column in 0..<Self.columns {
                for row in 0..<Self.rows {
                    let level = HeatLevel(position: Double(row) / Double(Self.rows - 1))
                    let lit = row < Self.heights[column]
                    let rect = CGRect(
                        x: CGFloat(column) * (width + gap),
                        y: size.height - CGFloat(row + 1) * height - CGFloat(row) * gap,
                        width: width, height: height
                    )
                    let lens = lit ? Board.heat(level) : (level.band >= .hot ? Board.heat(level).opacity(0.16) : Board.lens)
                    context.fill(Path(roundedRect: rect, cornerRadius: 8), with: .color(lens))
                }
            }
        }
        .frame(width: 520, height: 520)
        .padding(44)
        .background(Board.flapBlack, in: RoundedRectangle(cornerRadius: 56, style: .continuous))
    }
}
