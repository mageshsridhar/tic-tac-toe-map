import SwiftUI

/// The rounded elbow from the current board down to one option.
struct BranchShape: Shape {
    var dx: CGFloat, y0: CGFloat, mid: CGFloat, y1: CGFloat

    func path(in _: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: y0))
        guard abs(dx) > 0.5 else {
            p.addLine(to: CGPoint(x: 0, y: y1))
            return p
        }
        let r = min(12, abs(dx) / 2), s: CGFloat = dx > 0 ? 1 : -1
        p.addLine(to: CGPoint(x: 0, y: mid - r))
        p.addQuadCurve(to: CGPoint(x: s * r, y: mid), control: CGPoint(x: 0, y: mid))
        p.addLine(to: CGPoint(x: dx - s * r, y: mid))
        p.addQuadCurve(to: CGPoint(x: dx, y: mid + r), control: CGPoint(x: dx, y: mid))
        p.addLine(to: CGPoint(x: dx, y: y1))
        return p
    }

    /// The point a fraction `t` of the way along the branch (corners taken as square).
    func point(at t: CGFloat) -> CGPoint {
        let pts = [CGPoint(x: 0, y: y0), CGPoint(x: 0, y: mid), CGPoint(x: dx, y: mid), CGPoint(x: dx, y: y1)]
        let lengths = zip(pts, pts.dropFirst()).map { hypot($1.x - $0.x, $1.y - $0.y) }
        var remaining = max(0, min(1, t)) * lengths.reduce(0, +)
        for (i, len) in lengths.enumerated() {
            if remaining <= len || i == lengths.count - 1 {
                let f = len == 0 ? 0 : remaining / len
                return CGPoint(x: pts[i].x + (pts[i + 1].x - pts[i].x) * f, y: pts[i].y + (pts[i + 1].y - pts[i].y) * f)
            }
            remaining -= len
        }
        return pts.last!
    }
}

/// The dot that travels down the chosen branch. Its progress animates.
struct TravelDot: Shape {
    var branch: BranchShape
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in _: CGRect) -> Path {
        let c = branch.point(at: progress)
        return Path(ellipseIn: CGRect(x: c.x - 6, y: c.y - 6, width: 12, height: 12))
    }
}

/// Right panel: the game so far, top to bottom, with the possible next moves in a row below.
struct MapView: View {
    @Environment(\.palette) private var palette
    @Bindable var model: GameModel

    // Camera: where the map content sits and how big it is.
    @State private var camScale: CGFloat = 1
    @State private var camOffset: CGSize = .zero
    @State private var size: CGSize = .zero
    // The viewer's own panning and zooming on top of the camera.
    @State private var pan: CGSize = .zero
    @GestureState private var dragging: CGSize = .zero
    @State private var zoom: CGFloat = 1
    @GestureState private var pinching: CGFloat = 1

    private typealias L = MapLayout

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                palette.surface
                content
                    .dynamicTypeSize(.large)   // fixed grid that zooms as a whole
                    .frame(width: 1, height: 1, alignment: .topLeading)
                    .scaleEffect(camScale * zoom * pinching, anchor: .topLeading)
                    .offset(x: camOffset.width + pan.width + dragging.width,
                            y: camOffset.height + pan.height + dragging.height)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 4)
                .updating($dragging) { v, s, _ in s = v.translation }
                .onEnded { v in pan.width += v.translation.width; pan.height += v.translation.height })
            .simultaneousGesture(MagnifyGesture()
                .updating($pinching) { v, s, _ in s = v.magnification }
                .onEnded { v in zoom = max(0.4, min(3, zoom * v.magnification)) })
            .overlay(alignment: .topLeading) { heading }
            .overlay(alignment: .topTrailing) {
                Button { moveCamera(animated: true) } label: {
                    Label("Recenter", systemImage: "scope")
                        .font(.ui(15, .semibold))
                        .foregroundStyle(palette.fg)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)   // HIG minimum hit target
                        .background(palette.surface, in: Capsule())
                        .overlay(Capsule().strokeBorder(palette.line, lineWidth: 2))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
                .keyboardShortcut("r", modifiers: .command)
                .padding(12)
            }
            .onAppear { size = geo.size; moveCamera(animated: false) }
            .onChange(of: geo.size) { _, new in
                // Only a real size change re-fits the map; it never snaps mid-animation otherwise.
                guard abs(new.width - size.width) >= 1 || abs(new.height - size.height) >= 1 else { return }
                size = new
                moveCamera(animated: false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.large, style: .continuous).strokeBorder(palette.line, lineWidth: 2))
        .onChange(of: model.mapVersion) { moveCamera(animated: !model.reduceMotion) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Game map")
    }

    // MARK: Heading

    private var heading: some View {
        let board = model.mapCurrent
        let n = model.mapHistory.count - 1
        let over = board.winner != nil
        return VStack(alignment: .leading, spacing: 2) {
            Text(over ? "Game over after \(n) moves" : n == 0 ? "Start: empty board" : "After move \(n)")
                .font(.ui(17, .heavy))
                .foregroundStyle(palette.fg)
                .accessibilityAddTraits(.isHeader)
            Text(over ? "Tap any earlier board to go back and try a different move."
                      : "Dashed boards are your options. Tap one to play it, or tap an earlier board to go back.")
                .font(.ui(13.5))
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 16).padding(.top, 14).padding(.trailing, 160)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .allowsHitTesting(false)
    }

    // MARK: Content

    private var content: some View {
        let path = model.mapHistory
        let n = path.count
        let current = path.last!
        let options = Game.options(for: current)
        let cy = CGFloat(n - 1) * L.pathSpacing
        let rowY = cy + L.gapToOptions
        let mid = cy + L.pathSize / 2 + (L.gapToOptions - L.pathSize / 2 - L.optionSize / 2) / 2
        let xs = options.indices.map { (CGFloat($0) - CGFloat(options.count - 1) / 2) * L.optionSpacing }
        let travel = model.travel
        let revealed = model.revealed

        return ZStack(alignment: .topLeading) {
            // Row labels (the map is laid out on a fixed grid and zooms as a whole, so its text keeps one size)
            ForEach(0..<n, id: \.self) { i in
                rowLabel(i == 0 ? "START" : "MOVE \(i)", x: -L.pathSize / 2 - 16, y: CGFloat(i) * L.pathSpacing)
            }
            if !options.isEmpty {
                rowLabel("NEXT", x: xs[0] - L.optionSize / 2 - 16, y: rowY)
            }

            // The path so far
            ForEach(1..<max(n, 1), id: \.self) { i in
                let isNew = i == n - 1
                Path { p in
                    p.move(to: CGPoint(x: 0, y: CGFloat(i - 1) * L.pathSpacing + L.pathSize / 2))
                    p.addLine(to: CGPoint(x: 0, y: CGFloat(i) * L.pathSpacing - L.pathSize / 2))
                }
                .trim(from: 0, to: isNew && !revealed ? 0 : 1)
                .stroke(palette.muted, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .animation(isNew ? .easeOut(duration: 0.32).delay(0.12) : nil, value: revealed)
            }

            // Branches to the options
            ForEach(Array(options.enumerated()), id: \.element.id) { j, option in
                let branch = BranchShape(dx: xs[j], y0: cy + L.pathSize / 2, mid: mid, y1: rowY - L.optionSize / 2)
                let hot = travel?.id == option.id
                branch
                    .trim(from: 0, to: revealed ? 1 : 0)
                    .stroke(hot ? palette.focus : palette.line,
                            style: StrokeStyle(lineWidth: hot ? 3 : 2, lineCap: .round, lineJoin: .round))
                    .animation(.easeOut(duration: 0.32).delay(0.38 + 0.045 * Double(j)), value: revealed)
                    .opacity(travel != nil && !hot ? 0.15 : 1)
                    .animation(.easeOut(duration: 0.22), value: travel?.id)
            }

            // Boards on the path
            ForEach(0..<n, id: \.self) { i in
                pathNode(i, board: path[i], isLast: i == n - 1, revealed: revealed)
            }

            // Option boards
            ForEach(Array(options.enumerated()), id: \.element.id) { j, option in
                optionNode(option, x: xs[j], y: rowY, index: j, revealed: revealed)
            }

            // The traveling dot
            if let travel, let j = options.firstIndex(where: { $0.id == travel.id }) {
                let branch = BranchShape(dx: xs[j], y0: cy + L.pathSize / 2, mid: mid, y1: rowY - L.optionSize / 2)
                TravelDot(branch: branch, progress: travel.progress)
                    .fill(palette.focus)
                    .overlay(TravelDot(branch: branch, progress: travel.progress).stroke(palette.surface, lineWidth: 2))
            }
        }
    }

    private func rowLabel(_ text: String, x: CGFloat, y: CGFloat) -> some View {
        Text(text)
            .font(.ui(10, .heavy)).kerning(0.6)
            .foregroundStyle(palette.muted)
            .frame(width: 80, alignment: .trailing)
            .position(x: x - 40, y: y)
    }

    @ViewBuilder
    private func pathNode(_ i: Int, board: Board, isLast: Bool, revealed: Bool) -> some View {
        let winner = board.winner
        let stroke: Color = isLast ? (winner.map { palette.color($0) } ?? palette.focus) : palette.line
        let sliding = isLast && i > 0 && !revealed
        let y = CGFloat(i) * L.pathSpacing
        Button { model.goTo(i) } label: {
            MiniBoard(board: board, size: L.pathSize, stroke: stroke, lineWidth: isLast ? 3 : 2)
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .allowsHitTesting(!isLast)
        .accessibilityLabel(isLast ? "Current position" : "Go back to \(i == 0 ? "the start" : "move \(i)")")
        .offset(sliding ? model.slideFrom : .zero)
        .animation(isLast ? .easeOut(duration: 0.42) : nil, value: revealed)
        .position(x: 0, y: y)

        if isLast {
            let v = Solver.shared.value(of: board)
            VStack(alignment: .leading, spacing: 2) {
                if let winner {
                    Text(winner.label).font(.ui(13, .heavy)).foregroundStyle(palette.ink(winner))
                } else {
                    Text("Best play: \(v.label)").font(.ui(13, .heavy)).foregroundStyle(palette.ink(v))
                    Text("\(Solver.shared.endings(from: board).count) endings possible")
                        .font(.ui(12, .semibold)).foregroundStyle(palette.muted)
                }
            }
            .frame(width: 170, alignment: .leading)
            .opacity(revealed ? 1 : 0)
            .animation(.easeOut(duration: 0.26).delay(0.36), value: revealed)
            .position(x: L.pathSize / 2 + 16 + 85, y: y)
        }
    }

    private func optionNode(_ option: Option, x: CGFloat, y: CGFloat, index j: Int, revealed: Bool) -> some View {
        let chosen = model.travel?.id == option.id
        let dimmed = model.travel != nil && !chosen
        let peeked = model.peekKey == option.id
        let winner = option.board.winner
        let shown = winner ?? option.value
        return Button { model.play(option.cells[0]) } label: {
            // The board sits exactly on the row; its labels hang below it.
            MiniBoard(board: option.board, size: L.optionSize,
                      stroke: chosen ? palette.focus : peeked ? palette.fg : palette.edge,
                      lineWidth: chosen || peeked ? 3 : 2,
                      dashed: !(chosen || peeked))
                .frame(width: 120, height: L.optionSize)
                .overlay(alignment: .top) {
                    VStack(spacing: 4) {
                        Text(shown.label).font(.ui(13, .heavy)).foregroundStyle(palette.ink(shown))
                        Text("\(option.endings) ending\(option.endings == 1 ? "" : "s")")
                            .font(.ui(12, .semibold)).foregroundStyle(palette.muted)
                        if option.cells.count > 1 {
                            Text("\(option.cells.count) squares").font(.ui(12, .semibold)).foregroundStyle(palette.muted)
                        }
                    }
                    .fixedSize()
                    .offset(y: L.optionSize + 8)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .onHover { inside in model.peekKey = inside ? option.id : (model.peekKey == option.id ? nil : model.peekKey) }
        .accessibilityLabel("Play this move. \(option.value.label) with best play, \(option.endings) endings possible")
        .opacity(dimmed ? 0.15 : 1)
        .animation(.easeOut(duration: 0.22), value: model.travel?.id)
        .opacity(revealed ? 1 : 0)
        .offset(y: revealed ? 0 : -12)
        .animation(.spring(response: 0.32, dampingFraction: 0.62).delay(0.56 + 0.045 * Double(j)), value: revealed)
        .position(x: x, y: y)
    }

    // MARK: Camera

    /// Frames the current board and its options, or the whole path once the game is over.
    private func moveCamera(animated: Bool) {
        guard size.width > 0 else { return }
        let W = size.width, H = size.height, top0 = L.headerHeight
        let n = CGFloat(model.mapHistory.count)
        let m = CGFloat(Game.options(for: model.mapCurrent).count)
        var k: CGFloat, cx: CGFloat, cy: CGFloat
        if m == 0 {
            let h = (n - 1) * L.pathSpacing + L.pathSize + 40, w = L.pathSize + 260
            k = min(1.3, (H - top0 - 20) / h, (W - 24) / w)
            cx = 60
            cy = (n - 1) * L.pathSpacing / 2
        } else {
            let top = (n - 1) * L.pathSpacing - (n > 1 ? L.pathSpacing * 0.85 : L.pathSize / 2 + 10)
            let bottom = (n - 1) * L.pathSpacing + L.gapToOptions + L.optionSize / 2 + 64
            let half = max(L.pathSize / 2 + 200, (m - 1) * L.optionSpacing / 2 + L.optionSize / 2 + 70) + 40
            k = max(0.4, min(1.5, (H - top0 - 16) / (bottom - top), (W - 24) / (2 * half)))
            cx = 0
            cy = (top + bottom) / 2
        }
        let target = CGSize(width: (W / 2 - k * cx).rounded(), height: (top0 + (H - top0) / 2 - k * cy).rounded())
        withAnimation(animated ? .easeInOut(duration: 0.52) : nil) {
            camScale = k
            camOffset = target
            pan = .zero
            zoom = 1
        }
    }
}
