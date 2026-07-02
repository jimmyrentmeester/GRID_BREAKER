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
    /// Earn-only unlock (Cosmetics 2.0). Non-nil = prestige: never purchasable,
    /// granted permanently by `PrestigeUnlocks.sync` once the feat is achieved.
    var prestige: Prestige? = nil
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
        // ── Prestige (earn-only — the aspirational shelf, listed last) ──────────
        Palette(id: "circuit", name: "Circuit", cost: 0,
                background: Color(red: 0.01, green: 0.045, blue: 0.025),
                primary:    Color(red: 0.25, green: 1.00, blue: 0.55),   // PCB trace green
                secondary:  Color(red: 1.00, green: 0.58, blue: 0.25),   // copper
                accent:     Color(red: 0.90, green: 0.97, blue: 0.92),   // solder silver
                gridDim:    Color(red: 0.12, green: 0.38, blue: 0.22),
                prestige:   .stars(24)),
        Palette(id: "monolithgold", name: "Monolith Gold", cost: 0,
                background: Color(red: 0.05, green: 0.035, blue: 0.01),
                primary:    Color(red: 1.00, green: 0.83, blue: 0.30),   // rich gold
                secondary:  Color(red: 1.00, green: 0.95, blue: 0.75),   // champagne
                accent:     Color(red: 1.00, green: 0.68, blue: 0.16),   // deep amber
                gridDim:    Color(red: 0.42, green: 0.32, blue: 0.10),
                prestige:   .allStars),
    ]

    static func byID(_ id: String) -> Palette { all.first { $0.id == id } ?? classic }
}

/// A purchasable tap-trail skin (cosmetic) — a neon "data stream" that connects
/// your successive taps with a fading beam (plus a node at each tap), so even a
/// tap-only game leaves a real trail. Colors resolve through the equipped palette.
struct TrailSkin: Identifiable, Sendable, Equatable {
    enum Dot: Sendable { case circle, square, diamond }
    /// `chrome` is a fixed metallic silver-white — a prestige look that reads as
    /// chrome under every equipped palette (the others resolve through the palette).
    enum Tint: Sendable { case primary, secondary, accent, chrome }
    let id: String
    let name: String
    let cost: Int
    let dot: Dot
    let tint: Tint
    let size: CGFloat        // node size at each tap
    let lineWidth: CGFloat   // beam thickness connecting taps
    let dashed: Bool         // segmented beam (e.g. pixel) vs. solid
    /// Earn-only unlock (Cosmetics 2.0) — same rule as `Palette.prestige`.
    var prestige: Prestige? = nil

    var isOff: Bool { id == "none" }
    func color() -> Color {
        switch tint {
        case .primary:   return NeonTheme.cyan
        case .secondary: return NeonTheme.magenta
        case .accent:    return NeonTheme.gold
        case .chrome:    return Color(red: 0.93, green: 0.96, blue: 1.00)
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
        // ── Prestige (earn-only — the aspirational shelf, listed last) ──────────
        TrailSkin(id: "chrome",   name: "Chrome",   cost: 0, dot: .circle, tint: .chrome, size: 8,  lineWidth: 3.5, dashed: false, prestige: .stars(12)),
        TrailSkin(id: "daybreak", name: "Daybreak", cost: 0, dot: .circle, tint: .accent, size: 11, lineWidth: 5.5, dashed: false, prestige: .dailyStreak(7)),
    ]
    static func byID(_ id: String) -> TrailSkin { all.first { $0.id == id } ?? none }
    /// Equipped skin — set at launch + on equip (mirrors `NeonTheme.current`).
    static var equipped: TrailSkin = none
}

/// A purchasable node glyph set (cosmetic): alternate glyphs for the daemons and
/// hazards on the grid. Render-layer only — colors, rings, hitboxes, lifespans and
/// the functional signage (fever bolt, power-up icons, DAEMON SET numbers) never
/// change, so every set stays as learnable as Classic. The firewall glyph must keep
/// reading as "danger" in every set (it's the one node you must never tap).
struct GlyphSet: Identifiable, Sendable, Equatable {
    /// One node glyph: an SF Symbol, or a text character drawn in the mono font
    /// (runes / kanji / box-drawing — all system-font, no assets).
    enum Glyph: Sendable, Equatable {
        case symbol(String)
        case text(String)
    }
    let id: String
    let name: String
    let cost: Int
    let standard: Glyph
    let armored: Glyph      // shell intact
    let breached: Glyph     // shell cracked (one hit left)
    let firewall: Glyph
    let cache: Glyph
    let worm: Glyph
    let intrusion: Glyph
}

enum GlyphSets {
    static let classic = GlyphSet(
        id: "classic", name: "Classic", cost: 0,
        standard: .symbol("circle.grid.cross.fill"),
        armored:  .symbol("lock.shield.fill"),
        breached: .symbol("lock.open.fill"),
        firewall: .symbol("exclamationmark.triangle.fill"),
        cache:    .symbol("square.stack.3d.up.fill"),
        worm:     .symbol("scribble.variable"),
        intrusion: .symbol("hexagon.fill"))

    static let all: [GlyphSet] = [
        classic,
        // Blocky segment glyphs — an old handheld's LCD. The firewall stays a triangle.
        GlyphSet(id: "lcd", name: "Retro LCD", cost: 700,
                 standard: .text("▦"), armored: .text("▣"), breached: .text("▢"),
                 firewall: .text("▲"), cache: .text("◆"), worm: .text("∿"),
                 intrusion: .text("▓")),
        // Elder futhark — arcane sigils in the machine. Algiz (ᛉ) spikes = hazard.
        GlyphSet(id: "runes", name: "Runes", cost: 800,
                 standard: .text("ᚠ"), armored: .text("ᛟ"), breached: .text("ᚢ"),
                 firewall: .text("ᛉ"), cache: .text("ᛜ"), worm: .text("ᛋ"),
                 intrusion: .text("ᛞ")),
        // Cyberpunk signage: 閉/開 = closed/open shell, 危 = danger, 宝 = treasure,
        // 虫 = worm/bug, 敵 = enemy. Meaning-bearing, on-theme.
        GlyphSet(id: "neotokyo", name: "Neo-Tokyo", cost: 900,
                 standard: .text("デ"), armored: .text("閉"), breached: .text("開"),
                 firewall: .text("危"), cache: .text("宝"), worm: .text("虫"),
                 intrusion: .text("敵")),
    ]

    static func byID(_ id: String) -> GlyphSet { all.first { $0.id == id } ?? classic }
    /// Equipped set — applied at launch + on equip (mirrors `NeonTheme.current`).
    static var equipped: GlyphSet = classic
}

/// An app-icon cosmetic. `iconName` is the alternate `.appiconset` name passed to
/// `setAlternateIconName` (nil = the primary icon). Equipped state lives in iOS
/// itself (`UIApplication.alternateIconName`), not in the save.
struct AppIconStyle: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    /// Asset-catalog name for `setAlternateIconName`; nil = primary icon.
    let iconName: String?
    var prestige: Prestige? = nil
}

enum AppIconStyles {
    static let all: [AppIconStyle] = [
        AppIconStyle(id: "classic", name: "Classic", iconName: nil),
        // The prestige icon for cracking the whole campaign — the Monolith in gold.
        AppIconStyle(id: "monolith", name: "Monolith Gold", iconName: "AppIconMonolith",
                     prestige: .campaignComplete),
    ]
}

/// The prestige-unlock sweep (Cosmetics 2.0). Lives in the UI layer because the UI
/// owns the cosmetics catalog (GameStore is deliberately catalog-agnostic); the pure
/// rule itself is `Prestige.met` in Core. Idempotent, retroactive (a player who
/// already has 24★ is granted on the next sweep) and permanent (grants never revoke).
enum PrestigeUnlocks {
    /// Grant anything newly earned; returns display names for the celebration toast.
    @MainActor
    static func sync(store: GameStore) -> [String] {
        var out: [String] = []
        let stars = store.totalStars
        func met(_ p: Prestige) -> Bool {
            p.met(totalStars: stars, campaignProgress: store.campaignProgress,
                  dailyStreak: store.lastDailyStreak)
        }
        for p in Palettes.all {
            if let pr = p.prestige, met(pr), store.grantPalette(id: p.id) {
                out.append("\(p.name.uppercased()) PALETTE")
            }
        }
        for t in TrailSkins.all {
            if let pr = t.prestige, met(pr), store.grantTrail(id: t.id) {
                out.append("\(t.name.uppercased()) TRAIL")
            }
        }
        for i in AppIconStyles.all {
            if let pr = i.prestige, met(pr), store.grantIcon(id: i.id) {
                out.append("\(i.name.uppercased()) APP ICON")
            }
        }
        return out
    }
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

    /// Presents a "chrome" screen (menu/shop/codex/onboarding) as a centered column.
    ///
    /// - iPhone: caps to `maxWidth` and centers (the cap exceeds the screen width, so
    ///   it's effectively a no-op — the phone layout fills the screen).
    /// - iPad: lays the content out on a phone-width *design canvas* and **uniformly
    ///   scales it up** to fill the screen height, so type, icons and spacing all grow
    ///   together (a phone-sized column with phone-sized fonts looks tiny on a 4:3 iPad).
    ///   Scaling the whole canvas keeps the composition identical to iPhone, just bigger,
    ///   and keeps any inner `ScrollView` viewport correct (its height scales to fill).
    func playColumn(_ maxWidth: CGFloat = 480) -> some View {
        modifier(PlayColumn(base: maxWidth))
    }
}

/// Implements `playColumn` — see its doc. iPad uses a scaled design canvas; the scale
/// is capped so it never blows the column wider than a comfortable reading measure.
struct PlayColumn: ViewModifier {
    let base: CGFloat
    @Environment(\.horizontalSizeClass) private var hSize

    func body(content: Content) -> some View {
        if hSize == .regular {
            // iPad: scale a `base`-wide design canvas up to fill the height.
            GeometryReader { geo in
                // Scale to fill height, but cap so the column stays a readable width and
                // we don't over-magnify on very tall/large iPads.
                let byHeight = geo.size.height / 900.0       // 900pt ≈ the phone design height
                let byWidth  = (geo.size.width * 0.82) / base // leave a neon margin around it
                let scale = max(1.15, min(1.7, min(byHeight, byWidth)))
                content
                    .frame(width: base, height: geo.size.height / scale)
                    .scaleEffect(scale)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            }
        } else {
            content
                .frame(maxWidth: base)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
