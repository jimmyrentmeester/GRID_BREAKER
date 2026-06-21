import SwiftUI

/// TOP RUNS — endless leaderboard + cross-mode stats (ported from iOS).
struct HighScoresView: View {
    let scores: [HighScoreEntry]
    var dailyBest: Int = 0
    var campaignProgress: Int = 0
    var campaignTotal: Int = 0
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("TOP RUNS")
                .font(.system(size: 24, weight: .heavy, design: .monospaced))
                .foregroundStyle(NeonTheme.cyan)
                .neonGlow(NeonTheme.cyan, radius: 8)

            HStack(spacing: 10) {
                statBox("DAILY BEST", dailyBest > 0 ? "\(dailyBest)" : "—", NeonTheme.magenta)
                statBox("CAMPAIGN", "\(campaignProgress)/\(campaignTotal)", NeonTheme.gold)
            }

            Text("ENDLESS")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(NeonTheme.textDim).tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if scores.isEmpty {
                Spacer()
                Text("// no runs logged yet")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(NeonTheme.textDim)
                Spacer()
            } else {
                VStack(spacing: 10) {
                    // Bare ForEach(0..<count) — Skip's Range overload takes no `id:` (#40).
                    ForEach(0..<scores.count) { idx in
                        let entry = scores[idx]
                        HStack {
                            Text("\(idx + 1).")
                                .foregroundStyle(NeonTheme.textDim)
                                .frame(width: 28, alignment: .leading)
                            Text("\(entry.score)")
                                .foregroundStyle(idx == 0 ? NeonTheme.gold : NeonTheme.cyan)
                            Spacer()
                            Text(Self.dateString(entry.date))
                                .foregroundStyle(NeonTheme.textDim)
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                        }
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                    }
                }
                Spacer()
            }

            TerminalButton(title: "BACK", color: NeonTheme.magenta, action: onBack)
        }
        .padding(24)
    }

    private func statBox(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 20, weight: .heavy, design: .monospaced)).foregroundStyle(color)
            Text(label).font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(NeonTheme.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.4), lineWidth: 1)))
    }

    /// Short "d MMM HH:mm" — manual DateFormatter (Skip's Text(_:format: .dateTime) is unreliable).
    private static func dateString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d MMM HH:mm"
        return f.string(from: d)
    }
}
