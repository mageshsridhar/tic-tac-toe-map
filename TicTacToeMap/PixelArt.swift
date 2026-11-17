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
/// A Shape rather than a Canvas, so its colour fades with the theme switch.
struct PixelMark: View {
    let mark: Character

    var body: some View {
        PixelMarkShape(points: mark == "X" ? PixelArt.x7 : PixelArt.o7).fill(.foreground)
    }
}

private struct PixelMarkShape: Shape {
    let points: [(Int, Int)]

    func path(in rect: CGRect) -> Path {
        let px = floor(min(rect.width, rect.height) / 7)
        let ox = rect.minX + floor((rect.width - px * 7) / 2)
        let oy = rect.minY + floor((rect.height - px * 7) / 2)
        var path = Path()
        for (x, y) in points {
            path.addRect(CGRect(x: ox + CGFloat(x) * px, y: oy + CGFloat(y) * px, width: px, height: px))
        }
        return path
    }
}

/// A small board for the map: rounded frame, grid, winning squares and 5x5 pixel marks.
/// Each layer is a Shape filled with a palette colour, so the whole board fades
/// smoothly when the theme changes (a Canvas would repaint in one frame).
struct MiniBoard: View {
    @Environment(\.palette) private var palette
    let board: Board
    let size: CGFloat
    var stroke: Color
    var lineWidth: CGFloat = 2
    var dashed = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
        let geo = MiniBoardGeometry(size: size)
        ZStack {
            shape.fill(palette.surface)
            MiniBoardLayer(geo.winPath(board.winningCells)).fill(palette.win)
            MiniBoardLayer(geo.gridPath()).fill(palette.line)
            MiniBoardLayer(geo.marksPath(board, "X")).fill(palette.x)
            MiniBoardLayer(geo.marksPath(board, "O")).fill(palette.o)
            shape.strokeBorder(stroke, style: StrokeStyle(lineWidth: lineWidth, dash: dashed ? [4, 4] : []))
        }
        .frame(width: size, height: size)
    }
}

/// A fixed path wrapped as a Shape so it can be filled with an animatable colour.
private struct MiniBoardLayer: Shape {
    let fixed: Path
    init(_ fixed: Path) { self.fixed = fixed }
    func path(in rect: CGRect) -> Path { fixed }
}

private struct MiniBoardGeometry {
    let size: CGFloat
    var pad: CGFloat { (size * 0.1).rounded() }
    var cell: CGFloat { (size - 2 * pad) / 3 }

    func winPath(_ cells: Set<Int>) -> Path {
        var path = Path()
        for i in cells {
            let r = CGRect(x: pad + CGFloat(i % 3) * cell, y: pad + CGFloat(i / 3) * cell, width: cell, height: cell)
            path.addRoundedRect(in: r, cornerSize: CGSize(width: cell * 0.25, height: cell * 0.25))
        }
        return path
    }

    func gridPath() -> Path {
        let gw = max(2, (size / 30).rounded())
        var path = Path()
        for k in 1...2 {
            let v = CGRect(x: (pad + CGFloat(k) * cell - gw / 2).rounded(), y: pad, width: gw, height: 3 * cell)
            let h = CGRect(x: pad, y: (pad + CGFloat(k) * cell - gw / 2).rounded(), width: 3 * cell, height: gw)
            path.addRoundedRect(in: v, cornerSize: CGSize(width: gw / 2, height: gw / 2))
            path.addRoundedRect(in: h, cornerSize: CGSize(width: gw / 2, height: gw / 2))
        }
        return path
    }

    func marksPath(_ board: Board, _ mark: Character) -> Path {
        let p = max(2, (cell * 0.7 / 5).rounded())
        var path = Path()
        for (i, ch) in board.cells.enumerated() where ch == mark {
            let ox = (pad + (CGFloat(i % 3) + 0.5) * cell - 2.5 * p).rounded()
            let oy = (pad + (CGFloat(i / 3) + 0.5) * cell - 2.5 * p).rounded()
            for (x, y) in (mark == "X" ? PixelArt.x5 : PixelArt.o5) {
                path.addRect(CGRect(x: ox + CGFloat(x) * p, y: oy + CGFloat(y) * p, width: p, height: p))
            }
        }
        return path
    }
}
