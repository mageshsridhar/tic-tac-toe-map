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

@Observable
final class GameModel {
    /// The game as played. The board panel always shows this.
    var history: [Board] = [.empty]
    /// What the map shows. It trails `history` briefly while a move animates.
    var mapHistory: [Board] = [.empty]

    var travel: Travel?
    /// False for the moment between a redraw and the grow-in animation.
    var revealed = true
    /// Where the newest board on the path starts its slide from, relative to its final spot.
    var slideFrom: CGSize = .zero
    /// Bumped whenever the map redraws, so the camera knows to move.
    var mapVersion = 0
    /// The option being pointed at, from the board or the map.
    var peekKey: String?
    var reduceMotion = false

    private var token = 0

    var current: Board { history.last! }
    var mapCurrent: Board { mapHistory.last! }
    var movesPlayed: Int { history.count - 1 }

    func play(_ cell: Int) {
        let before = current
        guard before.cells[cell] == ".", before.winner == nil else { return }
        let next = before.placing(cell)
        let chosen = next.canonical
        let options = Game.options(for: before)
        let j = options.firstIndex { $0.id == chosen } ?? 0
        let x = (CGFloat(j) - CGFloat(options.count - 1) / 2) * MapLayout.optionSpacing
        slideFrom = CGSize(width: x, height: MapLayout.gapToOptions - MapLayout.pathSpacing)

        let mapWasInSync = mapHistory == history
        history.append(next)
        peekKey = nil
        token += 1
        let myToken = token

        // Skip the walk if motion is reduced, or if the map is still catching up on an earlier move.
        guard !reduceMotion, mapWasInSync else {
            commitMap(animated: !reduceMotion)
            return
        }
        travel = Travel(id: chosen, progress: 0)
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.42)) {
                self.travel?.progress = 1
            } completion: {
                guard myToken == self.token else { return }
                self.commitMap(animated: true)
            }
        }
    }

    func goTo(_ index: Int) {
        guard index < history.count - 1 else { return }
        token += 1
        history = Array(history.prefix(index + 1))
        peekKey = nil
        commitMap(animated: false)
    }

    func undo() { goTo(history.count - 2) }
    func restart() { goTo(0) }

    private func commitMap(animated: Bool) {
        var quiet = Transaction()
        quiet.disablesAnimations = true
        withTransaction(quiet) {
            travel = nil
            mapHistory = history
            revealed = !animated
        }
        mapVersion += 1
        if animated {
            DispatchQueue.main.async { self.revealed = true }
        }
    }
}
