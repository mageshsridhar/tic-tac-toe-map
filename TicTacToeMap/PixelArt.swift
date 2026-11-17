import SwiftUI

/// The 8-bit X and O. The board uses chunky 7x7 sprites; the map's small boards use 5x5.
enum PixelArt {
    static func pixels(_ rows: [String]) -> [(Int, Int)] {
        rows.enumerated().flatMap { y, row in row.enumerated().compactMap { x, c in c == "#" ? (x, y) : nil } }
    }

    static let x7 = pixels(["##...##", "###.###", ".#####.", "..###..", ".#####.", "###.###", "##...##"])
    static let o7 = pixels(["..###..", ".#####.", "##...##", "##...##", "##...##", ".#####.", "..###.."])
    static let x5 = pixels(["#...#", ".#.#.", "..#..", ".#.#.", "#...#"])
    static let o5 = pixels([".###.", "#...#", "#...#", "#...#", ".###."])
}

/// A pixel-art mark that fills its frame, drawn in the current foreground style.
struct PixelMark: View {
    let mark: Character

    var body: some View {
        Canvas { context, size in
            let points = mark == "X" ? PixelArt.x7 : PixelArt.o7
            let px = floor(min(size.width, size.height) / 7)
            let ox = floor((size.width - px * 7) / 2), oy = floor((size.height - px * 7) / 2)
            var path = Path()
            for (x, y) in points {
                path.addRect(CGRect(x: ox + CGFloat(x) * px, y: oy + CGFloat(y) * px, width: px, height: px))
            }
            context.fill(path, with: .foreground)
        }
    }
}

/// A small board for the map: rounded frame, grid, winning squares and 5x5 pixel marks.
struct MiniBoard: View {
    @Environment(\.palette) private var palette
    let board: Board
    let size: CGFloat
    var stroke: Color
    var lineWidth: CGFloat = 2
    var dashed = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
        ZStack {
            shape.fill(palette.surface)
            Canvas { context, _ in drawInside(context) }
            shape.strokeBorder(stroke, style: StrokeStyle(lineWidth: lineWidth, dash: dashed ? [4, 4] : []))
        }
        .frame(width: size, height: size)
    }

    private func drawInside(_ context: GraphicsContext) {
        let pad = (size * 0.1).rounded()
        let c = (size - 2 * pad) / 3
        let wins = board.winningCells
        for i in wins {
            let r = CGRect(x: pad + CGFloat(i % 3) * c, y: pad + CGFloat(i / 3) * c, width: c, height: c)
            context.fill(Path(roundedRect: r, cornerRadius: c * 0.25), with: .color(palette.win))
        }
        let gw = max(2, (size / 30).rounded())
        for k in 1...2 {
            let v = CGRect(x: (pad + CGFloat(k) * c - gw / 2).rounded(), y: pad, width: gw, height: 3 * c)
            let h = CGRect(x: pad, y: (pad + CGFloat(k) * c - gw / 2).rounded(), width: 3 * c, height: gw)
            context.fill(Path(roundedRect: v, cornerRadius: gw / 2), with: .color(palette.line))
            context.fill(Path(roundedRect: h, cornerRadius: gw / 2), with: .color(palette.line))
        }
        let p = max(2, (c * 0.7 / 5).rounded())
        for (i, ch) in board.cells.enumerated() where ch != "." {
            let ox = (pad + (CGFloat(i % 3) + 0.5) * c - 2.5 * p).rounded()
            let oy = (pad + (CGFloat(i / 3) + 0.5) * c - 2.5 * p).rounded()
            var path = Path()
            for (x, y) in (ch == "X" ? PixelArt.x5 : PixelArt.o5) {
                path.addRect(CGRect(x: ox + CGFloat(x) * p, y: oy + CGFloat(y) * p, width: p, height: p))
            }
            context.fill(path, with: .color(palette.mark(ch)))
        }
    }
}
