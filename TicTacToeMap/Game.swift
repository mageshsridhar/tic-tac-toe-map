import Foundation

/// How a finished game ended, or what a position leads to with perfect play.
/// The raw order (X wins, O wins, draw) is also the order of the endings meter.
enum Outcome: Int, Comparable, CaseIterable {
    case x = 0, o = 1, draw = 2

    static func < (a: Outcome, b: Outcome) -> Bool { a.rawValue < b.rawValue }

    var label: String {
        switch self {
        case .x: "X wins"
        case .o: "O wins"
        case .draw: "Draw"
        }
    }

    /// Total number of each ending among the 138 (rotations and reflections removed).
    var total: Int {
        switch self {
        case .x: 91
        case .o: 44
        case .draw: 3
        }
    }
}

/// A 3x3 board stored as 9 characters: "X", "O" or "." for empty, row by row.
struct Board: Hashable {
    var cells: [Character]

    init(_ string: String) { cells = Array(string) }
    static let empty = Board(".........")

    var key: String { String(cells) }
    var marks: Int { cells.filter { $0 != "." }.count }

    /// X always starts, so it is X's turn whenever both players have the same number of marks.
    var turn: Character {
        let x = cells.filter { $0 == "X" }.count
        let o = cells.filter { $0 == "O" }.count
        return x == o ? "X" : "O"
    }

    func placing(_ index: Int) -> Board {
        var next = self
        next.cells[index] = turn
        return next
    }

    var winner: Outcome? {
        for line in Game.lines {
            let p = cells[line[0]]
            if p != "." && p == cells[line[1]] && p == cells[line[2]] { return p == "X" ? .x : .o }
        }
        return cells.contains(".") ? nil : .draw
    }

    var winningCells: Set<Int> {
        guard let w = winner, w != .draw else { return [] }
        let mark: Character = w == .x ? "X" : "O"
        var result = Set<Int>()
        for line in Game.lines where line.allSatisfy({ cells[$0] == mark }) { result.formUnion(line) }
        return result
    }

    /// The same position in one standard orientation, so rotations and reflections compare equal.
    var canonical: String {
        Game.symmetries.map { t in String(t.map { cells[$0] }) }.min()!
    }
}

/// One possible next move as shown in the map. Moves that give the same position
/// after a rotation or reflection are grouped, and `cells` lists every square that gives it.
struct Option: Identifiable {
    let id: String          // canonical key of the resulting position
    let board: Board        // the resulting position, in the orientation actually played
    var cells: [Int]
    let value: Outcome      // result with perfect play from here
    let endings: Int        // how many of the 138 endings are still reachable
}

enum Game {
    static let lines: [[Int]] = [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]]

    /// The 8 symmetries of the square: 4 rotations, each with and without a mirror flip.
    static let symmetries: [[Int]] = {
        let rotate = [6, 3, 0, 7, 4, 1, 8, 5, 2]
        let mirror = [2, 1, 0, 5, 4, 3, 8, 7, 6]
        func compose(_ a: [Int], _ b: [Int]) -> [Int] { b.map { a[$0] } }
        var result = [Array(0..<9)]
        for _ in 0..<3 { result.append(compose(result.last!, rotate)) }
        return result + result.map { compose($0, mirror) }
    }()

    static func options(for board: Board) -> [Option] {
        guard board.winner == nil else { return [] }
        var order: [String] = []
        var byKey: [String: Option] = [:]
        for cell in 0..<9 where board.cells[cell] == "." {
            let next = board.placing(cell)
            let key = next.canonical
            if byKey[key] != nil {
                byKey[key]!.cells.append(cell)
            } else {
                order.append(key)
                byKey[key] = Option(id: key, board: next, cells: [cell],
                                    value: Solver.shared.value(of: next),
                                    endings: Solver.shared.endings(from: next).count)
            }
        }
        return order.map { byKey[$0]! }
    }
}

/// Solves every position once (765 of them up to symmetry): the perfect-play result,
/// and which finished boards can still be reached.
final class Solver {
    static let shared = Solver()

    private var values: [String: Outcome] = [:]
    private var reachable: [String: Set<String>] = [:]

    /// All 138 finished boards, ordered X wins, O wins, draws, then by number of marks.
    let allEndings: [String]
    let endingNumber: [String: Int]

    private init() {
        var values: [String: Outcome] = [:]
        var reachable: [String: Set<String>] = [:]
        func solve(_ key: String) {
            if values[key] != nil { return }
            let board = Board(key)
            if let w = board.winner {
                values[key] = w
                reachable[key] = [key]
                return
            }
            let xToMove = board.turn == "X"
            func rank(_ o: Outcome) -> Int {
                switch o {
                case .x: xToMove ? 2 : 0
                case .o: xToMove ? 0 : 2
                case .draw: 1
                }
            }
            var best: Outcome?
            var ends = Set<String>()
            for cell in 0..<9 where board.cells[cell] == "." {
                let child = board.placing(cell).canonical
                solve(child)
                let v = values[child]!
                if best == nil || rank(v) > rank(best!) { best = v }
                ends.formUnion(reachable[child]!)
            }
            values[key] = best!
            reachable[key] = ends
        }
        let start = Board.empty.canonical
        solve(start)
        self.values = values
        self.reachable = reachable

        allEndings = reachable[start]!.sorted { a, b in
            let ba = Board(a), bb = Board(b)
            let (wa, wb) = (ba.winner!, bb.winner!)
            if wa != wb { return wa < wb }
            if ba.marks != bb.marks { return ba.marks < bb.marks }
            return a < b
        }
        endingNumber = Dictionary(uniqueKeysWithValues: allEndings.enumerated().map { ($1, $0 + 1) })
    }

    func value(of board: Board) -> Outcome { values[board.canonical]! }
    func endings(from board: Board) -> Set<String> { reachable[board.canonical]! }
}
