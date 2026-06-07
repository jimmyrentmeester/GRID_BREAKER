import SwiftUI

/// Centralized neon-cyberpunk design tokens (ground-truth Part 2.4: always use
/// explicit theme colors, never rely on system semantic colors — guards
/// contrast on a forced-dark game). Art direction: "Neon Cyberpunk Terminal"
/// (brief 10.6) — jet-black field, cyan/purple grid, magenta/cyan daemons.
enum NeonTheme {
    static let background = Color(red: 0.02, green: 0.02, blue: 0.05)
    static let gridLine   = Color(red: 0.20, green: 0.85, blue: 0.95)   // electric cyan
    static let gridLineDim = Color(red: 0.45, green: 0.25, blue: 0.85)  // purple
    static let cyan       = Color(red: 0.20, green: 0.95, blue: 1.00)
    static let magenta    = Color(red: 1.00, green: 0.20, blue: 0.80)
    static let danger     = Color(red: 1.00, green: 0.18, blue: 0.30)   // firewall red
    static let gold       = Color(red: 1.00, green: 0.82, blue: 0.25)   // fever bonus
    static let textPrimary = Color.white
    static let textDim     = Color(white: 0.65)

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
