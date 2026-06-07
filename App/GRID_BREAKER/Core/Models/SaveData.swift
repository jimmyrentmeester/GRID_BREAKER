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
    /// Number of campaign cores cleared (core N is unlocked when this >= N-1).
    var campaignProgress: Int = 0

    enum CodingKeys: String, CodingKey { case version, cyberdeck, highScores, soundEnabled, campaignProgress }

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

// MARK: - Tolerant decoding (back-compatible persistence, ground-truth Part 3.3)
//
// Synthesized Codable does NOT apply property defaults for missing keys, so a
// save written by an older build (lacking a newer field) would otherwise fail to
// decode and silently wipe the player's progress. These custom decoders fill any
// missing field with its default. Defined in extensions so the memberwise inits
// (e.g. `Cyberdeck()`, `.starter`) are preserved.

extension Cyberdeck {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        ramLevel = try c.decodeIfPresent(Int.self, forKey: .ramLevel) ?? ramLevel
        decodeSpeedLevel = try c.decodeIfPresent(Int.self, forKey: .decodeSpeedLevel) ?? decodeSpeedLevel
        shieldLevel = try c.decodeIfPresent(Int.self, forKey: .shieldLevel) ?? shieldLevel
        credits = try c.decodeIfPresent(Int.self, forKey: .credits) ?? credits
    }
}

extension HighScoreEntry {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        let score = try c.decode(Int.self, forKey: .score)
        let date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date(timeIntervalSince1970: 0)
        self.init(id: id, score: score, date: date)
    }
}

extension SaveData {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? version
        cyberdeck = try c.decodeIfPresent(Cyberdeck.self, forKey: .cyberdeck) ?? cyberdeck
        highScores = try c.decodeIfPresent([HighScoreEntry].self, forKey: .highScores) ?? highScores
        soundEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? soundEnabled
        campaignProgress = try c.decodeIfPresent(Int.self, forKey: .campaignProgress) ?? campaignProgress
    }
}
