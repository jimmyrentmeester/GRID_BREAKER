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
        Palette(id: "ultraviolet", name: "Ultraviolet", cost: 800,
                background: Color(red: 0.04, green: 0.01, blue: 0.09),
                primary:    Color(red: 0.66, green: 0.40, blue: 1.00),
                secondary:  Color(red: 1.00, green: 0.30, blue: 0.86),
                accent:     Color(red: 0.55, green: 0.86, blue: 1.00),
                gridDim:    Color(red: 0.36, green: 0.18, blue: 0.58)),
        Palette(id: "inferno", name: "Inferno", cost: 1000,
                background: Color(red: 0.07, green: 0.02, blue: 0.01),
                primary:    Color(red: 1.00, green: 0.46, blue: 0.16),
                secondary:  Color(red: 1.00, green: 0.22, blue: 0.26),
                accent:     Color(red: 1.00, green: 0.84, blue: 0.34),
                gridDim:    Color(red: 0.46, green: 0.16, blue: 0.08)),
        Palette(id: "wireframe", name: "Wireframe", cost: 1500,
                background: Color(red: 0.03, green: 0.03, blue: 0.045),
                primary:    Color(red: 0.86, green: 0.93, blue: 1.00),
                secondary:  Color(red: 0.52, green: 0.60, blue: 0.72),
                accent:     Color(red: 0.78, green: 1.00, blue: 1.00),
                gridDim:    Color(red: 0.30, green: 0.34, blue: 0.42)),
    ]

    static func byID(_ id: String) -> Palette { all.first { $0.id == id } ?? classic }
}

/// A purchasable tap-trail skin (cosmetic) — a neon "data stream" that connects
/// your successive taps with a fading beam (plus a node at each tap), so even a
/// tap-only game leaves a real trail. Colors resolve through the equipped palette.
struct TrailSkin: Identifiable, Sendable, Equatable {
    enum Dot: Sendable { case circle, square, diamond }
    enum Tint: Sendable { case primary, secondary, accent }
    let id: String
    let name: String
    let cost: Int
    let dot: Dot
    let tint: Tint
    let size: CGFloat        // node size at each tap
    let lineWidth: CGFloat   // beam thickness connecting taps
    let dashed: Bool         // segmented beam (e.g. pixel) vs. solid

    var isOff: Bool { id == "none" }
    func color() -> Color {
        switch tint {
        case .primary:   return NeonTheme.cyan
        case .secondary: return NeonTheme.magenta
        case .accent:    return NeonTheme.gold
        }
    }

    /// Stroke style for the connecting beam at a given (faded) width.
    func beamStyle(width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round,
                    dash: dashed ? [max(0.5, width * 0.15), width * 1.5] : [])
    }

    /// A node shape (circle/square/diamond) centered at `p`, for Canvas filling.
    func dotPath(at p: CGPoint, size: CGFloat) -> Path {
        let r = CGRect(x: p.x - size / 2, y: p.y - size / 2, width: size, height: size)
        switch dot {
        case .circle: return Path(ellipseIn: r)
        case .square: return Path(roundedRect: r, cornerRadius: max(1, size * 0.2))
        case .diamond:
            var d = Path()
            d.move(to: CGPoint(x: r.midX, y: r.minY))
            d.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            d.addLine(to: CGPoint(x: r.midX, y: r.maxY))
            d.addLine(to: CGPoint(x: r.minX, y: r.midY))
            d.closeSubpath()
            return d
        }
    }
}

enum TrailSkins {
    static let none = TrailSkin(id: "none", name: "None", cost: 0, dot: .circle, tint: .primary, size: 0, lineWidth: 0, dashed: false)
    static let all: [TrailSkin] = [
        none,
        TrailSkin(id: "comet",  name: "Comet",      cost: 0,   dot: .circle,  tint: .primary,   size: 9,  lineWidth: 4,   dashed: false),
        TrailSkin(id: "pixel",  name: "Pixel Dust", cost: 400, dot: .square,  tint: .secondary, size: 9,  lineWidth: 5,   dashed: true),
        TrailSkin(id: "spark",  name: "Spark",      cost: 600, dot: .circle,  tint: .accent,    size: 6,  lineWidth: 2.5, dashed: false),
        TrailSkin(id: "plasma", name: "Plasma",     cost: 900, dot: .diamond, tint: .secondary, size: 13, lineWidth: 7,   dashed: false),
        TrailSkin(id: "laser",  name: "Laser",      cost: 500, dot: .circle,  tint: .accent,    size: 4,  lineWidth: 2,   dashed: false),
        TrailSkin(id: "hexbits", name: "Hexbits",   cost: 650, dot: .square,  tint: .primary,   size: 10, lineWidth: 5,   dashed: true),
        TrailSkin(id: "void",   name: "Voidstream", cost: 1000, dot: .diamond, tint: .primary,  size: 12, lineWidth: 6.5, dashed: true),
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
    static let worm = Color(red: 0.55, green: 1.00, blue: 0.30)     // worm acid-green — fixed
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
