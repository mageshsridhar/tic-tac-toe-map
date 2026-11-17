import SwiftUI

/// The pastel palette, in a light and a dark version. Marks use the soft pastels;
/// small text uses the deeper "ink" shades so it stays readable.
struct Palette {
    var bg, surface, sunk, line, edge, fg, muted: Color
    var x, o, draw, xSoft, oSoft, dSoft, xInk, oInk, dInk: Color
    var win, winFg, focus: Color

    static let light = Palette(
        bg: Color(hex: 0xF6F3FA), surface: Color(hex: 0xFFFDFF), sunk: Color(hex: 0xF0ECF6),
        line: Color(hex: 0xE2DCEC), edge: Color(hex: 0xC2B8D6), fg: Color(hex: 0x403A55), muted: Color(hex: 0x776F8D),
        x: Color(hex: 0x7BA6E6), o: Color(hex: 0xEC8FA8), draw: Color(hex: 0xAEA8BF),
        xSoft: Color(hex: 0xE3EDFB), oSoft: Color(hex: 0xFCE6ED), dSoft: Color(hex: 0xEEEBF3),
        xInk: Color(hex: 0x3E6DB5), oInk: Color(hex: 0xB5506F), dInk: Color(hex: 0x6C6680),
        win: Color(hex: 0xFFF0B0), winFg: Color(hex: 0x403A55), focus: Color(hex: 0xA78BD8))

    static let dark = Palette(
        bg: Color(hex: 0x1E1B2B), surface: Color(hex: 0x262236), sunk: Color(hex: 0x221F31),
        line: Color(hex: 0x3A3550), edge: Color(hex: 0x5A5378), fg: Color(hex: 0xF1EDF8), muted: Color(hex: 0xB3ABC9),
        x: Color(hex: 0x9CC3F5), o: Color(hex: 0xF7A8BF), draw: Color(hex: 0xC3BDD3),
        xSoft: Color(hex: 0x2D3652), oSoft: Color(hex: 0x45293A), dSoft: Color(hex: 0x322E43),
        xInk: Color(hex: 0xACD0F8), oInk: Color(hex: 0xF9B8CA), dInk: Color(hex: 0xCDC7DB),
        win: Color(hex: 0x5C5232), winFg: Color(hex: 0xFFF6D6), focus: Color(hex: 0xCBB2F0))

    func mark(_ c: Character) -> Color { c == "X" ? x : o }
    func color(_ o: Outcome) -> Color { o == .x ? x : o == .o ? self.o : draw }
    func soft(_ o: Outcome) -> Color { o == .x ? xSoft : o == .o ? oSoft : dSoft }
    func ink(_ o: Outcome) -> Color { o == .x ? xInk : o == .o ? oInk : dInk }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

private struct PaletteKey: EnvironmentKey { static let defaultValue = Palette.light }
extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

/// One soft rounded typeface everywhere, like the web version's Nunito.
/// Sizes map to the nearest system text style, so all text follows Dynamic Type.
extension Font {
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(textStyle(for: size), design: .rounded, weight: weight)
    }

    private static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case 30...: .title          // 28
        case 24..<30: .title2       // 22
        case 19..<24: .title3       // 20
        case 16.5..<19: .headline   // 17
        case 15..<16.5: .subheadline // 15
        case 13..<15: .footnote     // 13
        case 12..<13: .caption      // 12
        default: .caption2          // 11
        }
    }
}

/// Square corners everywhere are rounded off with these radii.
enum Radius {
    static let large: CGFloat = 20
    static let medium: CGFloat = 14
    static let small: CGFloat = 10
}
