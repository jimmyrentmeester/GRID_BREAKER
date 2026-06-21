import SwiftUI

// MARK: - Neon theme (subset)

enum Neon {
    static let background = Color(red: 0.02, green: 0.02, blue: 0.05)
    static let cyan       = Color(red: 0.20, green: 0.95, blue: 1.00)
    static let magenta    = Color(red: 1.00, green: 0.20, blue: 0.80)
    static let gold       = Color(red: 1.00, green: 0.82, blue: 0.25)
    static let danger     = Color(red: 1.00, green: 0.25, blue: 0.30)
}

extension View {
    /// The neon glow signature: double-shadow halo (`.shadow` is implemented in SkipUI).
    func neonGlow(_ color: Color, radius: CGFloat = 10) -> some View {
        self.shadow(color: color.opacity(0.9), radius: radius)
            .shadow(color: color.opacity(0.5), radius: radius * 2)
    }
}

/// Root — launches an Endless session for now (menu/router is M4).
struct ContentView: View {
    var body: some View {
        GameView(config: GameConfig.endless(), seed: UInt64(20260621))
    }
}
