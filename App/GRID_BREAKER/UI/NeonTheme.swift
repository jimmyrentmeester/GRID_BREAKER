import SwiftUI

/// A purchasable neon color palette (cosmetic). Recolors the whole game. `danger`
/// is deliberately NOT part of a palette — firewall bombs must always read as red.
struct Palette: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let cost: Int            // Credits (0 = free/default)
    let background: Color
    let primary: Color       // was "cyan" — main daemon / accents
    let secondary: Color     // was "magenta" — armored / secondary
    let accent: Color        // was "gold" — fever / credits / highlights
    let gridDim: Color       // was "gridLineDim" — terminal grid lines
}

enum Palettes {
    static let classic = Palette(
        id: "classic", name: "Classic", cost: 0,
        background: Color(red: 0.02, green: 0.02, blue: 0.05),
        primary:    Color(red: 0.20, green: 0.95, blue: 1.00),
        secondary:  Color(red: 1.00, green: 0.20, blue: 0.80),
        accent:     Color(red: 1.00, green: 0.82, blue: 0.25),
        gridDim:    Color(red: 0.45, green: 0.25, blue: 0.85))

    static let all: [Palette] = [
        classic,
        Palette(id: "sunset", name: "Sunset Drive", cost: 500,
                background: Color(red: 0.07, green: 0.02, blue: 0.11),
                primary:    Color(red: 1.00, green: 0.32, blue: 0.58),
                secondary:  Color(red: 0.66, green: 0.36, blue: 1.00),
                accent:     Color(red: 1.00, green: 0.64, blue: 0.22),
                gridDim:    Color(red: 0.52, green: 0.20, blue: 0.62)),
        Palette(id: "toxic", name: "Toxic Leak", cost: 700,
                background: Color(red: 0.01, green: 0.05, blue: 0.02),
                primary:    Color(red: 0.30, green: 1.00, blue: 0.48),
                secondary:  Color(red: 0.72, green: 1.00, blue: 0.20),
                accent:     Color(red: 0.95, green: 0.95, blue: 0.30),
                gridDim:    Color(red: 0.16, green: 0.45, blue: 0.22)),
        Palette(id: "glacier", name: "Glacier", cost: 900,
                background: Color(red: 0.02, green: 0.04, blue: 0.09),
                primary:    Color(red: 0.55, green: 0.86, blue: 1.00),
                secondary:  Color(red: 0.32, green: 0.55, blue: 1.00),
                accent:     Color(red: 0.85, green: 0.95, blue: 1.00),
                gridDim:    Color(red: 0.24, green: 0.40, blue: 0.72)),
        Palette(id: "amber", name: "Amber Terminal", cost: 1200,
                background: Color(red: 0.06, green: 0.03, blue: 0.00),
                primary:    Color(red: 1.00, green: 0.76, blue: 0.26),
                secondary:  Color(red: 1.00, green: 0.50, blue: 0.12),
                accent:     Color(red: 1.00, green: 0.90, blue: 0.55),
                gridDim:    Color(red: 0.46, green: 0.30, blue: 0.08)),
    ]

    static func byID(_ id: String) -> Palette { all.first { $0.id == id } ?? classic }
}

/// A purchasable tap-trail skin (cosmetic) — the neon trail that follows the
/// player's finger. Colors resolve through the equipped palette so trails harmonize.
struct TrailSkin: Identifiable, Sendable, Equatable {
    enum Dot: Sendable { case circle, square, diamond }
    enum Tint: Sendable { case primary, secondary, accent }
    let id: String
    let name: String
    let cost: Int
    let dot: Dot
    let tint: Tint
    let size: CGFloat

    var isOff: Bool { id == "none" }
    func color() -> Color {
        switch tint {
        case .primary:   return NeonTheme.cyan
        case .secondary: return NeonTheme.magenta
        case .accent:    return NeonTheme.gold
        }
    }
}

enum TrailSkins {
    static let none = TrailSkin(id: "none", name: "None", cost: 0, dot: .circle, tint: .primary, size: 0)
    static let all: [TrailSkin] = [
        none,
        TrailSkin(id: "comet",  name: "Comet",      cost: 0,   dot: .circle,  tint: .primary,   size: 11),
        TrailSkin(id: "pixel",  name: "Pixel Dust", cost: 400, dot: .square,  tint: .secondary, size: 10),
        TrailSkin(id: "spark",  name: "Spark",      cost: 600, dot: .circle,  tint: .accent,    size: 7),
        TrailSkin(id: "plasma", name: "Plasma",     cost: 900, dot: .diamond, tint: .secondary, size: 16),
    ]
    static func byID(_ id: String) -> TrailSkin { all.first { $0.id == id } ?? none }
    /// Equipped skin — set at launch + on equip (mirrors `NeonTheme.current`).
    static var equipped: TrailSkin = none
}

/// Centralized neon-cyberpunk design tokens. Colors come from the equipped
/// `Palette` (cosmetic), so swapping a palette recolors the whole game. `danger`,
/// `textPrimary` and `textDim` are fixed for readability (ground-truth Part 2.4).
enum NeonTheme {
    /// The equipped palette. Set at launch + when the player equips one.
    static var current: Palette = Palettes.classic

    static var background: Color { current.background }
    static var gridLine: Color { current.primary }
    static var gridLineDim: Color { current.gridDim }
    static var cyan: Color { current.primary }
    static var magenta: Color { current.secondary }
    static var gold: Color { current.accent }
    static let danger = Color(red: 1.00, green: 0.18, blue: 0.30)   // firewall red — fixed
    static let textPrimary = Color.white
    static let textDim = Color(white: 0.65)

    /// Reusable outer-glow modifier for neon elements.
    static func glow(_ color: Color, radius: CGFloat = 12) -> some View {
        Rectangle().fill(.clear).shadow(color: color, radius: radius)
    }
}

extension View {
    /// Applies a layered neon glow (calm at rest — use sparingly per Part 2.4).
    func neonGlow(_ color: Color, radius: CGFloat = 10) -> some View {
        self.shadow(color: color.opacity(0.9), radius: radius)
            .shadow(color: color.opacity(0.5), radius: radius * 2)
    }
}
