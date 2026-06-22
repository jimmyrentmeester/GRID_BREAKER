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

/// RAM-as-environment: the play field fills from the bottom and the bright "waterline"
/// recedes top→down as the RAM clock drains, so remaining RAM is felt in peripheral
/// vision without looking away from the grid. The body is low-opacity (keeps the grid
/// readable); the receding waterline is the bright, motion-carrying edge that the eye
/// catches. Colour shifts cyan→gold→red with the level, and the line rises smoothly on
/// every decode (a visible "top-up"). Optional — the slim top RAM bar stays as the
/// precise readout. Fed by the deterministic `ramFraction` (skill: dress real state).
struct RAMBackdrop: View {
    let fraction: Double          // 0…1 remaining RAM
    var feverActive: Bool = false
    let reduceMotion: Bool

    private var tint: Color {
        fraction > 0.5 ? NeonTheme.cyan
        : fraction > 0.25 ? NeonTheme.gold
        : NeonTheme.danger
    }

    var body: some View {
        let f = max(0, min(1, fraction))
        let peak = feverActive ? 0.08 : 0.16   // dampen behind the gold Fever atmosphere
        GeometryReader { geo in
            VStack(spacing: 0) {
                Rectangle()
                    .fill(tint)
                    .frame(height: 2.5)
                    .shadow(color: tint.opacity(0.9), radius: 6)
                    .opacity(0.9)
                LinearGradient(colors: [tint.opacity(peak), tint.opacity(0.03)],
                               startPoint: .bottom, endPoint: .top)
            }
            .frame(height: max(2.5, geo.size.height * f))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: f)
            .animation(.easeInOut(duration: 0.4), value: tint)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// Red screen-edge alarm when RAM is critically low. Breathes (slow pulse) to grab
/// peripheral attention; a static tint under Reduce Motion. Pairs with the existing
/// audio double-pulse + haptic on `.ramCritical`. Only the alarm — the waterline carries
/// the continuous level, so the two never animate at once (calm continuous vs late alarm).
struct RAMCriticalEdge: View {
    let active: Bool
    let reduceMotion: Bool
    @State private var pulse = false

    var body: some View {
        RadialGradient(colors: [.clear, NeonTheme.danger.opacity(0.30)],
                       center: .center, startRadius: 220, endRadius: 560)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .opacity(active ? (reduceMotion ? 0.7 : (pulse ? 1 : 0.45)) : 0)
            .animation(.easeInOut(duration: 0.45), value: active)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.65).repeatForever(autoreverses: true),
                       value: pulse)
            .onChange(of: active) { _, on in pulse = on && !reduceMotion }
            .onAppear { pulse = active && !reduceMotion }
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
