import SwiftUI
import Observation

/// Map spacing, in map points. The map runs top to bottom.
enum MapLayout {
    static let gapToOptions: CGFloat = 170   // from the current board down to the row of options
    static let pathSpacing: CGFloat = 108    // between past moves
    static let optionSpacing: CGFloat = 136  // across the row of options
    static let pathSize: CGFloat = 76        // boards on the path
    static let optionSize: CGFloat = 60      // option boards
    static let headerHeight: CGFloat = 78    // room for the map heading
}

/// The chosen option while a dot travels down its branch.
struct Travel: Equatable {
    var id: String
    var progress: CGFloat
}

/// The copy of the play board that turns to match the map's option and flies onto it.
struct Flight: Equatable {
    var id: String
    /// The board as played, before turning.
    var board: Board
    /// Mirror left-to-right first, then turn clockwise by `turns` quarter turns (-1 = one turn anticlockwise).
    var flip: Bool
    var turns: Int
    /// Frames in the "root" coordinate space.
    var from: CGRect
    var to: CGRect
    // Animated stages
    var oriented = false
    var landed = false
    var visible = true
}

@Observable
final class GameModel {
    /// The game as played. The board panel always shows this.
    var history: [Board] = [.empty]
    /// The same moves as the map draws them. Each one is the option board it was reached
    /// through, so the map never switches orientation under the viewer.
    private var oriented: [Board] = [.empty]
    /// What the map shows. It trails `oriented` briefly while a move animates.
    var mapHistory: [Board] = [.empty]

    var travel: Travel?
    /// While going back, the map fades out every board after this one before it rebuilds.
    var fadeAfter: Int?
    var flight: Flight?
    /// False for the moment between a redraw and the grow-in animation.
    var revealed = true
    /// Where the newest board on the path starts its slide from, relative to its final spot.
    var slideFrom: CGSize = .zero
    /// Bumped whenever the map redraws, so the camera knows to move.
    var mapVersion = 0
    /// The option being pointed at, from the board or the map.
    var peekKey: String?
    var reduceMotion = false

    /// Where the play board and the map's option boards are on screen (root coordinate space).
    @ObservationIgnored var boardFrame: CGRect?
    @ObservationIgnored var optionFrames: [String: CGRect] = [:]

    private var token = 0

    var current: Board { history.last! }
    var mapCurrent: Board { mapHistory.last! }
    var movesPlayed: Int { history.count - 1 }

    /// A move from the play board: a copy of the board turns to match the map and flies onto its option.
    func play(_ cell: Int) { move(cell, fromMap: false) }

    /// A move picked in the map. Any square giving that position will do on the play board.
    func play(_ option: Option) {
        guard let cell = (0..<9).first(where: { current.cells[$0] == "." && current.placing($0).canonical == option.id }) else { return }
        move(cell, fromMap: true)
    }

    private func move(_ cell: Int, fromMap: Bool) {
        let before = current
        guard before.cells[cell] == ".", before.winner == nil else { return }
        let next = before.placing(cell)
        let chosen = next.canonical
        let options = Game.options(for: oriented.last!)
        guard let j = options.firstIndex(where: { $0.id == chosen }) else { return }
        let target = options[j].board
        let x = (CGFloat(j) - CGFloat(options.count - 1) / 2) * MapLayout.optionSpacing
        slideFrom = CGSize(width: x, height: MapLayout.gapToOptions - MapLayout.pathSpacing)

        let mapWasInSync = mapHistory == oriented && flight == nil
        history.append(next)
        oriented.append(target)
        peekKey = nil
        token += 1
        let myToken = token

        // Skip the animation if motion is reduced, or if the map is still catching up on an earlier move.
        guard !reduceMotion, mapWasInSync else {
            commitMap(animated: !reduceMotion)
            return
        }
        if !fromMap, let from = boardFrame, let to = optionFrames[chosen],
           let turn = Self.orientation(from: next, to: target) {
            flight = Flight(id: chosen, board: next, flip: turn.flip, turns: turn.turns, from: from, to: to)
            DispatchQueue.main.async { self.orientCopy(myToken) }
        } else {
            walk(to: chosen, myToken)
        }
    }

    /// Stage 1: the copy lifts off the play board and turns to match the option.
    private func orientCopy(_ myToken: Int) {
        guard let f = flight, myToken == token else { return }
        let turning = f.flip || f.turns != 0
        let duration = turning ? 0.3 + 0.18 * Double((f.flip ? 1 : 0) + abs(f.turns)) : 0.12
        withAnimation(.easeInOut(duration: duration)) {
            flight?.oriented = true
        } completion: {
            self.flyCopy(myToken)
        }
    }

    /// Stage 2: the copy shrinks and flies onto its option, which lights up while the others dim.
    private func flyCopy(_ myToken: Int) {
        guard let f = flight, myToken == token else { return }
        travel = Travel(id: f.id, progress: 0)
        withAnimation(.smooth(duration: 0.55)) {
            flight?.landed = true
        } completion: {
            guard myToken == self.token else { return }
            // Stage 3: the copy melts into the option and the map carries on as before.
            withAnimation(.easeOut(duration: 0.18)) {
                self.flight?.visible = false
            } completion: {
                if myToken == self.token { self.flight = nil }
            }
            self.walk(to: f.id, myToken)
        }
    }

    /// The dot travels down the chosen branch, then the map moves on.
    private func walk(to id: String, _ myToken: Int) {
        travel = Travel(id: id, progress: 0)
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.42)) {
                self.travel?.progress = 1
            } completion: {
                guard myToken == self.token else { return }
                self.commitMap(animated: true)
            }
        }
    }

    /// Undo, New game, or tapping an earlier board on the map. The removed marks fade off the board,
    /// and the map rebuilds with the same grow-in animation as after a move while the camera glides back.
    func goTo(_ index: Int) {
        guard index < history.count - 1 else { return }
        token += 1
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
            history = Array(history.prefix(index + 1))
        }
        oriented = Array(oriented.prefix(index + 1))
        peekKey = nil
        slideFrom = .zero   // nothing slides in: the board is already on the path
        flight = nil
        travel = nil
        guard !reduceMotion else {
            commitMap(animated: false)
            return
        }
        let myToken = token
        withAnimation(.easeOut(duration: 0.18)) {
            fadeAfter = index
        } completion: {
            guard myToken == self.token else { return }
            self.commitMap(animated: true)
        }
    }

    func undo() { goTo(history.count - 2) }
    func restart() { goTo(0) }

    private func commitMap(animated: Bool) {
        var quiet = Transaction()
        quiet.disablesAnimations = true
        withTransaction(quiet) {
            travel = nil
            flight = nil
            fadeAfter = nil
            mapHistory = oriented
            revealed = !animated
        }
        mapVersion += 1
        if animated {
            DispatchQueue.main.async { self.revealed = true }
        }
    }

    /// The mirror and quarter turns that take board `a` to board `b`, using as few steps as possible.
    static func orientation(from a: Board, to b: Board) -> (flip: Bool, turns: Int)? {
        let mirror = [2, 1, 0, 5, 4, 3, 8, 7, 6]
        let clockwise = [6, 3, 0, 7, 4, 1, 8, 5, 2]
        var best: (flip: Bool, turns: Int)?
        for flip in [false, true] {
            var cells = flip ? mirror.map { a.cells[$0] } : a.cells
            for k in 0..<4 {
                if cells == b.cells {
                    let turns = k == 3 ? -1 : k
                    let cost = (flip ? 1 : 0) + abs(turns)
                    if best == nil || cost < (best!.flip ? 1 : 0) + abs(best!.turns) { best = (flip, turns) }
                }
                cells = clockwise.map { cells[$0] }
            }
        }
        return best
    }
}
