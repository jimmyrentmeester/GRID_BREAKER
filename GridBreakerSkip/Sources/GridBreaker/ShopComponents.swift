import SwiftUI

// MARK: - Confirm dialog (purchases) — ported from iOS

struct ConfirmDialog: View {
    let title: String
    let message: String
    var confirmLabel: String = "BUY"
    var confirmColor: Color = NeonTheme.gold
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
                .onTapGesture { onCancel() }   // Skip's onTapGesture wants a closure, not (perform:)
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(NeonTheme.textDim)
                Text(message)
                    .font(.system(size: 18, weight: .heavy, design: .monospaced))
                    .foregroundStyle(NeonTheme.textPrimary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 14) {
                    TerminalButton(title: confirmLabel, color: confirmColor, action: onConfirm)
                    TerminalButton(title: "CANCEL", color: NeonTheme.magenta, action: onCancel)
                }
                .padding(.top, 6)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(NeonTheme.background.opacity(0.95))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(confirmColor.opacity(0.6), lineWidth: 1.5))
            )
            .padding(40)
        }
    }
}

// MARK: - Purchase celebration (shared by the shops)

/// Brief "ACQUIRED" feedback on a completed purchase. (Haptics are an M3 no-op on Android;
/// `.spring` isn't resolvable in Skip → easeOut.)
@MainActor
func celebratePurchase(_ bought: Binding<String?>, _ name: String) {
    AudioEngine.shared.play(.purchase)
    withAnimation(.easeOut(duration: 0.3)) { bought.wrappedValue = name }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
        withAnimation(.easeOut(duration: 0.3)) {
            if bought.wrappedValue == name { bought.wrappedValue = nil }
        }
    }
}

/// A brief gold "ACQUIRED" reward card shown over a shop on a completed buy.
struct PurchaseFlash: View {
    let name: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: sfSym("checkmark.seal.fill"))
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(NeonTheme.gold).neonGlow(NeonTheme.gold, radius: 16)
            Text("ACQUIRED")
                .font(.system(size: 24, weight: .heavy, design: .monospaced))
                .foregroundStyle(NeonTheme.gold).neonGlow(NeonTheme.gold, radius: 8)
            Text(name)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(NeonTheme.textPrimary)
                .multilineTextAlignment(.center)
        }
        .padding(30)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(NeonTheme.background.opacity(0.92))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(NeonTheme.gold.opacity(0.6), lineWidth: 1.5)))
        .neonGlow(NeonTheme.gold, radius: 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

// MARK: - Guided onboarding hint

struct GuidedHint: View {
    let icon: String
    let text: String
    var done: Bool = false
    var actionLabel: String? = nil
    var action: () -> Void = {}

    private var tint: Color { done ? NeonTheme.gold : NeonTheme.cyan }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(tint)
                .neonGlow(tint, radius: 5)
            Text(text)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(NeonTheme.textPrimary)
            Spacer(minLength: 4)
            if done, let actionLabel {
                Button(action: action) {
                    Text(actionLabel)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(NeonTheme.cyan)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).stroke(NeonTheme.cyan, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(tint.opacity(0.10))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.6), lineWidth: 1)))
    }
}
