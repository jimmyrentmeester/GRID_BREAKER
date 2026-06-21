import SwiftUI

/// Shared neon button used across the chrome screens (ported from iOS). Uses
/// `.buttonStyle(.plain)` since SkipUI has no custom-ButtonStyle conformance.
struct TerminalButton: View {
    let title: String
    let color: Color
    var wide: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: wide ? .infinity : nil)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(color, lineWidth: 1.5)
                        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.12)))
                )
                .neonGlow(color, radius: 6)
        }
        .buttonStyle(.plain)
    }
}
