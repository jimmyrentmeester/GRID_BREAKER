import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Haptics

/// Thin wrapper over UIKit feedback generators. Haptics replace the missing
/// physical resistance of a touchscreen (brief §10.6). No-op where UIKit is
/// absent so the Core/UI stays portable.
@MainActor
final class Haptics {
    /// Global on/off (player preference), set at launch + from Settings. Mirrors
    /// `AudioEngine.enabled` / `NeonTheme.current` — a simple shared switch.
    static var enabled = true

    #if canImport(UIKit)
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let notify = UINotificationFeedbackGenerator()
    #endif

    func prepare() {
        #if canImport(UIKit)
        light.prepare(); medium.prepare(); rigid.prepare()
        #endif
    }

    enum Tap { case light, medium, rigid, soft }

    func impact(_ tap: Tap) {
        guard Haptics.enabled else { return }
        #if canImport(UIKit)
        switch tap {
        case .light:  light.impactOccurred()
        case .medium: medium.impactOccurred(intensity: 0.9)
        case .rigid:  rigid.impactOccurred()
        case .soft:   soft.impactOccurred(intensity: 0.6)
        }
        #endif
    }

    /// Fire a tap at an explicit intensity (0…1). Used to ramp feel with a streak.
    func impact(_ tap: Tap, intensity: Double) {
        guard Haptics.enabled else { return }
        #if canImport(UIKit)
        let i = CGFloat(max(0, min(1, intensity)))
        switch tap {
        case .light:  light.impactOccurred(intensity: i)
        case .medium: medium.impactOccurred(intensity: i)
        case .rigid:  rigid.impactOccurred(intensity: i)
        case .soft:   soft.impactOccurred(intensity: i)
        }
        #endif
    }

    /// A nimble decode's tactile weight, ramped by the clean-hit `streak` toward the
    /// fever `threshold` (mirrors the rising decode arpeggio). The chain climbs through
    /// generator *bands* (light → medium → rigid) so milestones land as felt "notches",
    /// with a smooth intensity ramp inside each band. Fever decodes hit sharp + full.
    func decodeStreak(_ streak: Int, threshold: Int, fever: Bool) {
        guard Haptics.enabled else { return }
        let denom = threshold > 0 ? Double(threshold) : 8
        let t = min(1, Double(max(0, streak)) / denom)
        if fever {
            impact(.rigid, intensity: 1.0)            // fever: every hit sharp + full
        } else if t >= 0.75 {
            impact(.rigid, intensity: 0.7 + 0.3 * t)  // near fever: sharp notch
        } else if t >= 0.40 {
            impact(.medium, intensity: 0.55 + 0.45 * t)
        } else {
            impact(.light, intensity: 0.5 + 0.4 * t)
        }
    }

    func error() {
        guard Haptics.enabled else { return }
        #if canImport(UIKit)
        notify.notificationOccurred(.error)
        #endif
    }

    func success() {
        guard Haptics.enabled else { return }
        #if canImport(UIKit)
        notify.notificationOccurred(.success)
        #endif
    }
}

// MARK: - Effect model

/// A one-shot visual flourish at a grid cell, produced by the view-model from a
/// real `GameEvent` — never invented by the view (skill §5, Part 2.5).
struct JuiceEffect: Identifiable {
    let id = UUID()
    let cell: Int
    let style: Style
    let color: Color
    /// Score gained, for the floating "+N" pop (nil when not a decode).
    let points: Int?
    /// Streak "heat", 0…1 — scales the burst (more particles, brighter flash, bigger
    /// pop) the deeper into a clean-hit chain you are. 0 for non-decode effects.
    var intensity: Double = 0

    enum Style: Equatable { case pop, breach, miss, shield, bomb }
}

extension Color {
    /// Linear RGB blend a→b at t∈0…1 (for the streak's cyan→gold "heating up" shift).
    static func blend(_ a: Color, _ b: Color, _ t: Double) -> Color {
        #if canImport(UIKit)
        let f = CGFloat(max(0, min(1, t)))
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        UIColor(a).getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        UIColor(b).getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return Color(red: ar + (br - ar) * f, green: ag + (bg - ag) * f, blue: ab + (bb - ab) * f)
        #else
        return t < 0.5 ? a : b
        #endif
    }
}

// MARK: - Effects overlay (particles, flash, floating numbers)

/// Renders transient effects over the grid, sharing the grid's cell geometry.
/// Holds its own short-lived state; each effect self-removes after its lifetime.
struct EffectsLayer: View {
    let cols: Int
    let cell: CGFloat
    let spacing: CGFloat
    let reduceMotion: Bool
    let seq: Int
    let drain: () -> [JuiceEffect]

    @State private var live: [JuiceEffect] = []

    private func center(_ index: Int) -> CGPoint {
        let col = index % cols, row = index / cols
        return CGPoint(x: CGFloat(col) * (cell + spacing) + cell / 2,
                       y: CGFloat(row) * (cell + spacing) + cell / 2)
    }

    var body: some View {
        ZStack {
            ForEach(live) { fx in
                EffectView(fx: fx, cellSize: cell, reduceMotion: reduceMotion)
                    .position(center(fx.cell))
            }
        }
        .allowsHitTesting(false)
        .onChange(of: seq) { _, _ in
            let fresh = drain()
            live.append(contentsOf: fresh)
            for fx in fresh {
                let life = fx.style == .pop ? 0.62 : 0.42
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(life * 1_000_000_000))
                    live.removeAll { $0.id == fx.id }
                }
            }
        }
    }
}

/// One effect's visuals: a white hit-flash, an optional neon particle burst, and
/// an optional floating score pop. Reduced-motion snaps everything off.
private struct EffectView: View {
    let fx: JuiceEffect
    let cellSize: CGFloat
    let reduceMotion: Bool
    @State private var p: CGFloat = 0

    // Burst grows with the streak heat: more sparks, a brighter flash, a bigger pop —
    // so a long chain visibly throws more energy. Capped to stay readable (skill §2).
    private var particleCount: Int {
        fx.style == .bomb ? 18 : 12 + Int((fx.intensity * 14).rounded())   // 12…26
    }
    private var showsBurst: Bool { !reduceMotion && (fx.style == .pop || fx.style == .bomb) }
    private var flashPeak: Double { fx.style == .pop ? 0.85 + fx.intensity * 0.15 : 0.85 }
    /// A negative event (miss / bomb) flashes red so an error reads as an error;
    /// positive events flash white. Previously every flash was white, so a miss
    /// looked just like a hit when the board got busy (issue #2).
    private var flashColor: Color {
        (fx.style == .miss || fx.style == .bomb) ? NeonTheme.danger : .white
    }
    private var popSize: CGFloat { 20 + CGFloat(fx.intensity) * 12 }
    private var popGlow: CGFloat { 4 + CGFloat(fx.intensity) * 6 }

    var body: some View {
        ZStack {
            // Hit-flash — intense white, gone within ~2 frames worth of progress.
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(flashColor)
                .frame(width: cellSize * 0.66, height: cellSize * 0.66)
                .opacity(Double(max(0, flashPeak - Double(p) * 3.2)))

            if showsBurst {
                ForEach(0..<particleCount, id: \.self) { i in
                    Circle()
                        .fill(fx.color)
                        .frame(width: 6, height: 6)
                        .neonGlow(fx.color, radius: 3)
                        .offset(offset(i))
                        .opacity(Double(1 - p))
                }
            }

            if let pts = fx.points {
                Text("+\(pts)")
                    .font(.system(size: popSize, weight: .heavy, design: .monospaced))
                    .foregroundStyle(fx.color)
                    .neonGlow(fx.color, radius: popGlow)
                    .offset(y: -p * 46)
                    .opacity(Double(1 - p))
            }
        }
        .onAppear {
            if reduceMotion {
                p = 1   // snap: no flash, no burst, no drift
            } else {
                withAnimation(.easeOut(duration: fx.style == .pop ? 0.62 : 0.42)) { p = 1 }
            }
        }
    }

    private func offset(_ i: Int) -> CGSize {
        let angle = (Double(i) / Double(particleCount)) * 2 * .pi
        let spread = fx.style == .bomb ? 0.95 : (0.7 + fx.intensity * 0.35)   // streak throws wider
        let dist = Double(p) * Double(cellSize) * spread
        return CGSize(width: cos(angle) * dist, height: sin(angle) * dist)
    }
}

// MARK: - Longevity + streak ambience

/// A subtle warm edge-glow that grows with your score — the arena quietly densifies
/// the longer (and higher) you play. Behind the grid and text, low opacity, and
/// dampened while Fever owns the screen with its own gold atmosphere.
struct HeatVignette: View {
    let level: Double          // 0…1 from score
    var dampened: Bool = false // true during Fever
    var body: some View {
        RadialGradient(
            colors: [.clear, NeonTheme.magenta.opacity(0.18)],
            center: .center, startRadius: 200, endRadius: 540
        )
        .opacity(max(0, min(1, level)) * (dampened ? 0.35 : 1))
        .animation(.easeInOut(duration: 0.8), value: level)
        .animation(.easeInOut(duration: 0.4), value: dampened)
        .allowsHitTesting(false)
    }
}

/// A brief neon border pulse at a streak milestone — momentum you can see building
/// before Fever triggers. One-shot per `trigger` bump; snaps off under Reduce Motion.
struct StreakPulseBorder: View {
    let trigger: Int
    let reduceMotion: Bool
    @State private var glow: Double = 0

    var body: some View {
        Rectangle()
            .stroke(NeonTheme.gold, lineWidth: 3)
            .blur(radius: 7)
            .opacity(glow * 0.55)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onChange(of: trigger) { _, new in
                guard !reduceMotion, new > 0 else { return }
                glow = 1
                withAnimation(.easeOut(duration: 0.5)) { glow = 0 }
            }
    }
}

/// A brief red screen-edge pulse on a negative event (mistap, daemon expiry) — a
/// global "you missed" signal that stays legible even when the board is busy and a
/// single-cell flash gets lost (issue #2). One-shot per `trigger` bump; snaps off
/// under Reduce Motion. Kept subtle (low opacity, fast fade) per skill §4 restraint.
struct ErrorFlashBorder: View {
    let trigger: Int
    let reduceMotion: Bool
    @State private var glow: Double = 0

    var body: some View {
        Rectangle()
            .stroke(NeonTheme.danger, lineWidth: 4)
            .blur(radius: 8)
            .opacity(glow * 0.6)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onChange(of: trigger) { _, new in
                guard new > 0 else { return }
                if reduceMotion {
                    // Reduced motion: a single brief static tint, no animated fade.
                    glow = 0.5
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 140_000_000)
                        glow = 0
                    }
                } else {
                    glow = 1
                    withAnimation(.easeOut(duration: 0.42)) { glow = 0 }
                }
            }
    }
}

// MARK: - RAM as environment (optional, Settings toggle)

/// RAM-as-environment: the screen-edge "containment frame" is the RAM meter. At full RAM
/// the whole perimeter is lit; as the clock drains the lit line **splits at top-centre and
/// the two ends descend evenly down both sides, meeting at the bottom when RAM hits 0** —
/// so the remaining RAM always sits low (you read "almost out" at the bottom, near the
/// grid, not up at the top). Colour shifts cyan→gold→red, a segment re-lights on each
/// decode (a visible "top-up"), and as 0 nears a red glow rises from the bottom edge.
/// On-theme (a system perimeter failing), never touches the grid interior, and structured
/// like the existing edge borders so it can't perturb layout. The slim top bar stays as
/// the precise readout. Fed by the deterministic `ramFraction` (skill: dress real state).
struct RAMPerimeterFrame: View {
    let fraction: Double          // 0…1 remaining RAM
    var feverActive: Bool = false
    let reduceMotion: Bool
    @State private var critPulse = false

    private var tint: Color {
        fraction > 0.5 ? NeonTheme.cyan
        : fraction > 0.25 ? NeonTheme.gold
        : NeonTheme.danger
    }
    private var critical: Bool { fraction < 0.15 }
    private var lineW: CGFloat { critical ? 4.5 : 3 }

    var body: some View {
        let f = max(0.0, min(1.0, fraction))
        // Red glow that rises from the bottom edge as RAM approaches 0.
        let glow = f < 0.25 ? (0.25 - f) / 0.25 : 0.0
        ZStack {
            // Dim full-perimeter rail — the "spent" arc still reads as a frame.
            PerimeterDrain(fraction: 1)
                .stroke(tint.opacity(0.10),
                        style: StrokeStyle(lineWidth: lineW, lineCap: .round, lineJoin: .round))
            // Remaining RAM: two symmetric arcs from the descending fronts down to the
            // bottom-centre, glowing.
            PerimeterDrain(fraction: f)
                .stroke(tint, style: StrokeStyle(lineWidth: lineW, lineCap: .round, lineJoin: .round))
                .shadow(color: tint.opacity(0.85), radius: critical ? 9 : 5)
                .opacity(critical && !reduceMotion ? (critPulse ? 1.0 : 0.55)
                         : (feverActive ? 0.7 : 0.95))
            // Upward red glow from the bottom edge near depletion.
            RadialGradient(colors: [NeonTheme.danger.opacity(0.6), .clear],
                           center: UnitPoint(x: 0.5, y: 1.04), startRadius: 0, endRadius: 280)
                .opacity(glow * (reduceMotion ? 0.6 : (critPulse ? 0.7 : 0.35)))
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: f)
        .animation(.easeInOut(duration: 0.4), value: tint)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.65).repeatForever(autoreverses: true),
                   value: critPulse)
        .onChange(of: critical) { _, c in critPulse = c && !reduceMotion }
        .onAppear { critPulse = critical && !reduceMotion }
    }
}

/// The remaining-RAM perimeter as two symmetric arcs. Both start at the descending
/// "front" (arclength `(1-fraction)·halfPerimeter` from top-centre) and run down to the
/// bottom-centre — so at full RAM the whole frame is drawn, and the two fronts glide down
/// the left/right edges and meet at the bottom as RAM → 0. Inset built in (no layout
/// padding) so the view behaves like a plain edge border.
private struct PerimeterDrain: Shape {
    var fraction: Double
    var inset: CGFloat = 4
    var animatableData: Double { get { fraction } set { fraction = newValue } }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let f = max(0.0, min(1.0, fraction))
        guard f > 0.001 else { return p }
        let r = rect.insetBy(dx: inset, dy: inset)
        let tc = CGPoint(x: r.midX, y: r.minY)
        let tr = CGPoint(x: r.maxX, y: r.minY)
        let br = CGPoint(x: r.maxX, y: r.maxY)
        let bc = CGPoint(x: r.midX, y: r.maxY)
        let tl = CGPoint(x: r.minX, y: r.minY)
        let bl = CGPoint(x: r.minX, y: r.maxY)
        let half = r.width + r.height                 // arclength of each half (TC→…→BC)
        let start = CGFloat(1.0 - f) * half           // descend point from top-centre
        appendArc(&p, [tc, tr, br, bc], from: start)  // right half
        appendArc(&p, [tc, tl, bl, bc], from: start)  // left half
        return p
    }

    /// Emit the polyline from arclength `s` (measured from the first vertex) to the end.
    private func appendArc(_ p: inout Path, _ v: [CGPoint], from s: CGFloat) {
        var acc: CGFloat = 0
        var started = false
        for i in 1..<v.count {
            let a = v[i - 1], b = v[i]
            let segLen = hypot(b.x - a.x, b.y - a.y)
            let segEnd = acc + segLen
            if !started {
                if s <= segEnd {
                    let t = segLen == 0 ? 0 : (s - acc) / segLen
                    p.move(to: CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
                    p.addLine(to: b)
                    started = true
                }
            } else {
                p.addLine(to: b)
            }
            acc = segEnd
        }
    }
}

// MARK: - Screen shake

/// Horizontal shake driven by an animatable 0→1 ramp (Part 2.2 / brief §10.6:
/// communicates the catastrophic impact of a firewall hit).
struct ShakeEffect: GeometryEffect {
    var amplitude: CGFloat = 10
    var shakes: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let dx = amplitude * (1 - animatableData) * sin(animatableData * .pi * 2 * shakes)
        return ProjectionTransform(CGAffineTransform(translationX: dx, y: 0))
    }
}

// MARK: - Fever Mode presentation

/// A mood-tinted atmosphere layer that cross-fades in during Fever Mode
/// (skill §2 atmosphere layer — behind the UI, low opacity, never over text).
struct FeverAtmosphere: View {
    let active: Bool

    var body: some View {
        RadialGradient(
            colors: [NeonTheme.gold.opacity(0.22), NeonTheme.magenta.opacity(0.10), .clear],
            center: .center, startRadius: 4, endRadius: 520
        )
        .opacity(active ? 1 : 0)
        .animation(.easeInOut(duration: 0.4), value: active)
        .allowsHitTesting(false)
    }
}

// MARK: - Button feel

/// Micro press-response for terminal buttons (skill §2: every tap a 0.06 s dip).
struct TerminalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.55),
                       value: configuration.isPressed)
    }
}
