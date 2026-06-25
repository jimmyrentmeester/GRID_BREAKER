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
    /// Consecutive-day streak on the Daily Hack, and the day key it was last counted on
    /// — the retention ritual (a reason to open the app every day).
    var dailyStreak: Int = 0
    var dailyStreakDay: String = ""
    /// Number of campaign cores cleared (core N is unlocked when this >= N-1).
    var campaignProgress: Int = 0
    /// Best score per campaign core, indexed by `core.id - 1` (grows as needed).
    /// Gives a cleared core a reason to be replayed.
    var campaignBests: [Int] = []
    /// Best star rating (0–3) per campaign core, indexed by `core.id - 1`. The replay
    /// mastery layer (★ clear / ★★ flawless-or-fast / ★★★ flawless-and-fast).
    var campaignStars: [Int] = []
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
    /// Render the RAM clock as a draining screen-edge containment frame on top of the
    /// slim top bar — easier to track without looking away from the grid. Preference,
    /// not progress.
    var ramBackgroundEnabled: Bool = true
    /// Endless run-modifier IDs currently enabled (harder run → more Credits). Persisted
    /// so the choice carries between runs.
    var enabledModifierIDs: [String] = []

    enum CodingKeys: String, CodingKey {
        case version, cyberdeck, highScores, soundEnabled, hapticsEnabled, campaignProgress, tutorialSeen
        case musicVolume, sfxVolume, dailyBestScore, dailyBestDay, dailyStreak, dailyStreakDay
        case ownedPaletteIDs, equippedPaletteID, ownedTrailIDs, equippedTrailID
        case starterCreditsGranted, campaignBests, campaignStars, ramBackgroundEnabled
        case enabledModifierIDs
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
        feverLevel = try c.decodeIfPresent(Int.self, forKey: .feverLevel) ?? feverLevel
        salvageLevel = try c.decodeIfPresent(Int.self, forKey: .salvageLevel) ?? salvageLevel
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
        hapticsEnabled = try c.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? hapticsEnabled
        musicVolume = try c.decodeIfPresent(Double.self, forKey: .musicVolume) ?? musicVolume
        sfxVolume = try c.decodeIfPresent(Double.self, forKey: .sfxVolume) ?? sfxVolume
        dailyBestScore = try c.decodeIfPresent(Int.self, forKey: .dailyBestScore) ?? dailyBestScore
        dailyBestDay = try c.decodeIfPresent(String.self, forKey: .dailyBestDay) ?? dailyBestDay
        dailyStreak = try c.decodeIfPresent(Int.self, forKey: .dailyStreak) ?? dailyStreak
        dailyStreakDay = try c.decodeIfPresent(String.self, forKey: .dailyStreakDay) ?? dailyStreakDay
        campaignProgress = try c.decodeIfPresent(Int.self, forKey: .campaignProgress) ?? campaignProgress
        campaignBests = try c.decodeIfPresent([Int].self, forKey: .campaignBests) ?? campaignBests
        campaignStars = try c.decodeIfPresent([Int].self, forKey: .campaignStars) ?? campaignStars
        tutorialSeen = try c.decodeIfPresent(Bool.self, forKey: .tutorialSeen) ?? tutorialSeen
        starterCreditsGranted = try c.decodeIfPresent(Bool.self, forKey: .starterCreditsGranted) ?? starterCreditsGranted
        ownedPaletteIDs = try c.decodeIfPresent([String].self, forKey: .ownedPaletteIDs) ?? ownedPaletteIDs
        if !ownedPaletteIDs.contains("classic") { ownedPaletteIDs.append("classic") }
        equippedPaletteID = try c.decodeIfPresent(String.self, forKey: .equippedPaletteID) ?? equippedPaletteID
        ownedTrailIDs = try c.decodeIfPresent([String].self, forKey: .ownedTrailIDs) ?? ownedTrailIDs
        if !ownedTrailIDs.contains("none") { ownedTrailIDs.append("none") }
        if !ownedTrailIDs.contains("comet") { ownedTrailIDs.append("comet") }
        equippedTrailID = try c.decodeIfPresent(String.self, forKey: .equippedTrailID) ?? equippedTrailID
        ramBackgroundEnabled = try c.decodeIfPresent(Bool.self, forKey: .ramBackgroundEnabled) ?? ramBackgroundEnabled
        enabledModifierIDs = try c.decodeIfPresent([String].self, forKey: .enabledModifierIDs) ?? enabledModifierIDs
    }
}
