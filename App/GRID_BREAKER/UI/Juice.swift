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
        #if canImport(UIKit)
        switch tap {
        case .light:  light.impactOccurred()
        case .medium: medium.impactOccurred(intensity: 0.9)
        case .rigid:  rigid.impactOccurred()
        case .soft:   soft.impactOccurred(intensity: 0.6)
        }
        #endif
    }

    func error() {
        #if canImport(UIKit)
        notify.notificationOccurred(.error)
        #endif
    }

    func success() {
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

    enum Style: Equatable { case pop, breach, miss, shield, bomb }
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

    private var particleCount: Int { fx.style == .bomb ? 18 : 12 }
    private var showsBurst: Bool { !reduceMotion && (fx.style == .pop || fx.style == .bomb) }

    var body: some View {
        ZStack {
            // Hit-flash — intense white, gone within ~2 frames worth of progress.
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white)
                .frame(width: cellSize * 0.66, height: cellSize * 0.66)
                .opacity(Double(max(0, 0.85 - p * 3.2)))

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
                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                    .foregroundStyle(fx.color)
                    .neonGlow(fx.color, radius: 4)
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
        let dist = Double(p) * Double(cellSize) * (fx.style == .bomb ? 0.95 : 0.7)
        return CGSize(width: cos(angle) * dist, height: sin(angle) * dist)
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

// MARK: - Flow (chill) atmosphere

/// A slow, low-opacity cyan/purple "breath" behind the grid in Flow mode — a calm
/// living backdrop that reinforces the meditative vibe (skill: the world feels
/// alive; diegetic calm). Static under Reduce Motion.
struct ChillAtmosphere: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false

    var body: some View {
        RadialGradient(
            colors: [NeonTheme.gridLineDim.opacity(0.20), NeonTheme.cyan.opacity(0.06), .clear],
            center: .center, startRadius: 40, endRadius: 540
        )
        .opacity((breathe && !reduceMotion) ? 0.9 : 0.55)
        .scaleEffect((breathe && !reduceMotion) ? 1.05 : 1.0)
        .animation(reduceMotion ? nil : .easeInOut(duration: 5).repeatForever(autoreverses: true), value: breathe)
        .onAppear { breathe = true }
        .allowsHitTesting(false)
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
