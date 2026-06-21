import Foundation

/// One persisted high-score entry.
struct HighScoreEntry: Codable, Sendable, Identifiable, Equatable {
    var id = UUID()
    var score: Int
    var date: Date

    enum CodingKeys: String, CodingKey { case id, score, date }
}

/// The whole persisted save: meta-progression + leaderboard.
///
/// Versioned + tolerant: every field has a default so older saves decode without
/// crashing when new fields are added (ground-truth Part 3.3). Bump `version`
/// when a migration is needed.
struct SaveData: Codable, Sendable {
    var version: Int = 1
    var cyberdeck: Cyberdeck = .starter
    var highScores: [HighScoreEntry] = []
    var soundEnabled: Bool = true
    var hapticsEnabled: Bool = true
    var musicVolume: Double = 0.85
    var sfxVolume: Double = 0.7
    /// Best score on the daily challenge, and the day key ("yyyy-MM-dd") it belongs
    /// to — a new day resets the comparison.
    var dailyBestScore: Int = 0
    var dailyBestDay: String = ""
    /// Number of campaign cores cleared (core N is unlocked when this >= N-1).
    var campaignProgress: Int = 0
    /// Best score per campaign core, indexed by `core.id - 1` (grows as needed).
    /// Gives a cleared core a reason to be replayed.
    var campaignBests: [Int] = []
    /// Whether the how-to-play explainer has been shown once.
    var tutorialSeen: Bool = false
    /// Whether the one-time starter-CR "payday" has been granted (during onboarding).
    var starterCreditsGranted: Bool = false
    /// Cosmetic palette IDs the player owns (Classic is always owned).
    var ownedPaletteIDs: [String] = ["classic"]
    /// Currently equipped palette ID.
    var equippedPaletteID: String = "classic"
    /// Tap-trail skin IDs owned ("none" + "comet" are free/default).
    var ownedTrailIDs: [String] = ["none", "comet"]
    /// Currently equipped tap-trail skin ID.
    var equippedTrailID: String = "comet"

    enum CodingKeys: String, CodingKey {
        case version, cyberdeck, highScores, soundEnabled, hapticsEnabled, campaignProgress, tutorialSeen
        case musicVolume, sfxVolume, dailyBestScore, dailyBestDay
        case ownedPaletteIDs, equippedPaletteID, ownedTrailIDs, equippedTrailID
        case starterCreditsGranted, campaignBests
    }

    static let empty = SaveData()

    /// Insert a score, keep the top `limit` sorted descending.
    mutating func insertScore(_ score: Int, on date: Date, limit: Int = 5) {
        guard score > 0 else { return }
        highScores.append(HighScoreEntry(score: score, date: date))
        highScores.sort { $0.score > $1.score }
        if highScores.count > limit { highScores.removeLast(highScores.count - limit) }
    }

    /// True if `score` would land on the (descending, capped) leaderboard.
    func isHighScore(_ score: Int, limit: Int = 5) -> Bool {
        guard score > 0 else { return false }
        return highScores.count < limit || score > (highScores.map(\.score).min() ?? 0)
    }
}

// MARK: - Decoding note (Android/Skip)
//
// The iOS build uses custom `init(from:)` decoders here for back-compatible
// persistence (synthesized Codable doesn't apply defaults for missing keys, so an
// old save lacking a new field would fail to decode). Those custom decoders use
// `decodeIfPresent(forKey: .X)`, which Skip can't transpile (pitfall #19: it can't
// infer `.X` on CodingKeys). Android has NO legacy saves — a fresh install starts
// from `.empty`, and every save the app writes is complete — so the synthesized
// Codable always has all keys. The custom decoders are therefore dropped here.
