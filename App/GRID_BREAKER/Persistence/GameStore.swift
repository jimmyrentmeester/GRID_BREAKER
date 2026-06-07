import Foundation

/// Owns the persisted meta-state (Cyberdeck + high scores) and the only paths
/// that mutate it. The authority for meta-progression (ground-truth Part 1.1):
/// the game session reads the deck, and reports its score here exactly once.
///
/// Persists JSON to UserDefaults — simple, non-secret save data. Decoding is
/// tolerant: a missing/corrupt blob falls back to a fresh save (Part 3.3).
@MainActor
@Observable
final class GameStore {
    private(set) var save: SaveData
    private let config: GameConfig
    private let defaults: UserDefaults
    private let key = "gridbreaker.save.v1"

    init(config: GameConfig = .default, defaults: UserDefaults = .standard) {
        self.config = config
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(SaveData.self, from: data) {
            self.save = decoded
        } else {
            self.save = .empty
        }
    }

    var cyberdeck: Cyberdeck { save.cyberdeck }
    var highScores: [HighScoreEntry] { save.highScores }

    /// Credits a given final score will award (for previewing on the HUD).
    func creditsForScore(_ score: Int) -> Int { config.credits(forScore: score) }

    func isHighScore(_ score: Int) -> Bool { save.isHighScore(score) }

    /// Record a finished session: pay credits once and update the leaderboard.
    /// Returns the credits awarded (for the game-over screen).
    @discardableResult
    func recordSession(score: Int, on date: Date) -> Int {
        let earned = config.credits(forScore: score)
        save.cyberdeck.credits += earned
        save.insertScore(score, on: date)
        persist()
        return earned
    }

    /// Attempt to buy one level of an upgrade. Returns true on success.
    @discardableResult
    func purchase(_ upgrade: CyberdeckUpgrade) -> Bool {
        let level = upgrade.currentLevel(in: save.cyberdeck)
        guard level < upgrade.maxLevel else { return false }
        let cost = upgrade.cost(atLevel: level)
        guard save.cyberdeck.credits >= cost else { return false }

        save.cyberdeck.credits -= cost
        switch upgrade {
        case .ram:         save.cyberdeck.ramLevel += 1
        case .decodeSpeed: save.cyberdeck.decodeSpeedLevel += 1
        case .shield:      save.cyberdeck.shieldLevel += 1
        }
        persist()
        return true
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(save) {
            defaults.set(data, forKey: key)
        }
    }
}
