import SwiftUI
import UIKit

@main
struct TicTacToeMapApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var model = GameModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// "light", "dark", or "" to follow the system until the toggle is used.
    @AppStorage("ttt-theme") private var savedTheme = ""
    @State private var isDark = ContentView.startsDark()

    private var palette: Palette { isDark ? .dark : .light }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= 900
            Group {
                if wide {
                    // Title, game and credit stack in the left column; the map takes the full height.
                    HStack(alignment: .top, spacing: 22) {
                        VStack(spacing: 18) {
                            header
                            GamePanel(model: model)
                            MadeByCard()
                        }
                        .frame(width: 380)
                        MapView(model: model)
                    }
                } else {
                    // Narrow windows (Split View, Slide Over): the game on top, the map below it.
                    VStack(spacing: 18) {
                        header.frame(width: 380)
                        GamePanel(model: model).frame(width: 380)
                        MapView(model: model)
                        MadeByCard().frame(width: 380)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(palette.bg.ignoresSafeArea())
        .environment(\.palette, palette)
        .preferredColorScheme(isDark ? .dark : .light)
        // Light tap on each move, a success tap when a game is won or drawn.
        .sensoryFeedback(trigger: model.history) { old, new in
            guard new.count > old.count, let last = new.last else { return nil }
            return last.winner != nil ? .success : .impact(weight: .light)
        }
        .onAppear { model.reduceMotion = reduceMotion }
        .onChange(of: reduceMotion) { _, v in model.reduceMotion = v }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Tic-Tac-Toe\nGame Map")
                .font(.ui(30, .heavy))
                .foregroundStyle(palette.fg)
                .lineSpacing(-2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Tic-Tac-Toe Game Map")
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button {
                // The palette fades between themes instead of switching instantly.
                withAnimation(.easeInOut(duration: 0.5)) { isDark.toggle() }
                savedTheme = isDark ? "dark" : "light"
            } label: {
                // Icon-only so it fits beside the title in the 380pt column.
                Image(systemName: isDark ? "sun.max" : "moon")
                    .font(.ui(17, .semibold))
                    .foregroundStyle(palette.fg)
                    .frame(width: 44, height: 44)   // HIG minimum hit target
                    .background(palette.surface, in: Circle())
                    .overlay(Circle().strokeBorder(palette.line, lineWidth: 2))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .hoverEffect(.highlight)
            .keyboardShortcut("d", modifiers: [.command, .shift])
            .accessibilityLabel(isDark ? "Switch to light mode" : "Switch to dark mode")
        }
    }

    /// Starts from the saved choice, otherwise the system appearance.
    private static func startsDark() -> Bool {
        switch UserDefaults.standard.string(forKey: "ttt-theme") {
        case "dark": return true
        case "light": return false
        default: return UIScreen.main.traitCollection.userInterfaceStyle == .dark
        }
    }
}

/// Credit card that fills the space under the game panel.
struct MadeByCard: View {
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "number.square.fill")
                .font(.ui(26, .semibold))
                .foregroundStyle(palette.focus)
                .frame(width: 44, height: 44)
                .background(palette.sunk, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("MADE BY")
                    .font(.ui(12, .heavy)).kerning(0.7)
                    .foregroundStyle(palette.muted)
                Text("Magesh Sridhar")
                    .font(.ui(17, .bold))
                    .foregroundStyle(palette.fg)
                Text("Built with SwiftUI")
                    .font(.ui(13))
                    .foregroundStyle(palette.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.large, style: .continuous).strokeBorder(palette.line, lineWidth: 2))
        .accessibilityElement(children: .combine)
    }
}
