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
    var soundEnabled: Bool { save.soundEnabled }

    func setSoundEnabled(_ on: Bool) {
        save.soundEnabled = on
        persist()
    }

    var hapticsEnabled: Bool { save.hapticsEnabled }
    func setHapticsEnabled(_ on: Bool) {
        save.hapticsEnabled = on
        persist()
    }

    // MARK: Endless run modifiers (harder run → more Credits)

    var enabledModifiers: [RunModifier] { RunModifier.from(ids: save.enabledModifierIDs) }
    /// Credit multiplier from the currently-enabled modifiers (1.0 = none).
    var runCreditMultiplier: Double { RunModifier.creditMultiplier(enabledModifiers) }
    func isModifierOn(_ id: String) -> Bool { save.enabledModifierIDs.contains(id) }
    func toggleModifier(_ id: String) {
        if let i = save.enabledModifierIDs.firstIndex(of: id) { save.enabledModifierIDs.remove(at: i) }
        else { save.enabledModifierIDs.append(id) }
        persist()
    }

    var musicVolume: Double { save.musicVolume }
    func setMusicVolume(_ v: Double) {
        save.musicVolume = min(1, max(0, v))
        persist()
    }

    var sfxVolume: Double { save.sfxVolume }
    func setSfxVolume(_ v: Double) {
        save.sfxVolume = min(1, max(0, v))
        persist()
    }

    var tutorialSeen: Bool { save.tutorialSeen }
    /// Whether the one-time starter Credits have been granted — also the reliable
    /// "this is a brand-new player" flag the launch flow keys off.
    var starterCreditsGranted: Bool { save.starterCreditsGranted }
    func markTutorialSeen() {
        guard !save.tutorialSeen else { return }
        save.tutorialSeen = true
        persist()
    }

    // MARK: Onboarding meta-loop (Phase B)

    /// The one-time "payday" granted at the end of onboarding so the shops aren't
    /// abstract — enough for a first Cyberdeck upgrade + a cheap cosmetic.
    static let starterCredits = 150

    /// Grant the starter CR once (idempotent). Returns the amount granted (0 if already
    /// granted), so the caller can drive a count-up to the right number.
    @discardableResult
    func grantStarterCredits() -> Int {
        guard !save.starterCreditsGranted else { return 0 }
        save.starterCreditsGranted = true
        save.cyberdeck.credits += Self.starterCredits
        persist()
        return Self.starterCredits
    }

    /// Wipe gameplay progress (Credits, upgrades, scores, cosmetics, campaign) to a
    /// fresh start. Keeps the player's *preferences* (sound/haptics) and that they've
    /// already seen the tutorial — those aren't "progress".
    func resetProgress() {
        var fresh = SaveData.empty
        fresh.soundEnabled = save.soundEnabled
        fresh.hapticsEnabled = save.hapticsEnabled
        fresh.musicVolume = save.musicVolume
        fresh.sfxVolume = save.sfxVolume
        fresh.tutorialSeen = save.tutorialSeen
        // Onboarding state isn't "gameplay progress" — keep it so we don't re-grant CR.
        fresh.starterCreditsGranted = save.starterCreditsGranted
        save = fresh
        persist()
    }

    // MARK: Cosmetics (palettes) — color-agnostic; the UI owns the catalog.

    var equippedPaletteID: String { save.equippedPaletteID }
    func ownsPalette(_ id: String) -> Bool { save.ownedPaletteIDs.contains(id) }

    // MARK: Prestige cosmetics (earn-only — Cosmetics 2.0)

    /// Total campaign stars earned across all cores (0…48).
    var totalStars: Int { save.campaignStars.reduce(0, +) }
    /// The last *counted* Daily-Hack streak, regardless of whether it has lapsed
    /// since — prestige grants are permanent, so "reached 7 at some point" counts.
    var lastDailyStreak: Int { save.dailyStreak }

    /// Grant an earn-only palette (idempotent, no Credits involved).
    /// Returns true only when newly granted — the caller celebrates on true.
    @discardableResult
    func grantPalette(id: String) -> Bool {
        guard !ownsPalette(id) else { return false }
        save.ownedPaletteIDs.append(id)
        persist()
        return true
    }

    /// Grant an earn-only trail (same contract as `grantPalette`).
    @discardableResult
    func grantTrail(id: String) -> Bool {
        guard !ownsTrail(id) else { return false }
        save.ownedTrailIDs.append(id)
        persist()
        return true
    }

    /// Buy a palette with Credits. Returns true on success.
    @discardableResult
    func buyPalette(id: String, cost: Int) -> Bool {
        guard !ownsPalette(id), save.cyberdeck.credits >= cost else { return false }
        save.cyberdeck.credits -= cost
        save.ownedPaletteIDs.append(id)
        persist()
        return true
    }

    /// Equip an owned palette.
    func equipPalette(_ id: String) {
        guard ownsPalette(id) else { return }
        save.equippedPaletteID = id
        persist()
    }

    var equippedTrailID: String { save.equippedTrailID }
    func ownsTrail(_ id: String) -> Bool { save.ownedTrailIDs.contains(id) }

    @discardableResult
    func buyTrail(id: String, cost: Int) -> Bool {
        guard !ownsTrail(id), save.cyberdeck.credits >= cost else { return false }
        save.cyberdeck.credits -= cost
        save.ownedTrailIDs.append(id)
        persist()
        return true
    }

    func equipTrail(_ id: String) {
        guard ownsTrail(id) else { return }
        save.equippedTrailID = id
        persist()
    }

    // MARK: Campaign

    var campaignProgress: Int { save.campaignProgress }
    /// Core 1 is always open; core N opens once the previous is cleared.
    func isUnlocked(_ core: DataCore) -> Bool { core.id <= save.campaignProgress + 1 }
    func isCleared(_ core: DataCore) -> Bool { core.id <= save.campaignProgress }
    /// Best score ever decoded on this core (0 = never attempted).
    func bestScore(for core: DataCore) -> Int {
        let idx = core.id - 1
        return idx >= 0 && idx < save.campaignBests.count ? save.campaignBests[idx] : 0
    }

    /// Best star rating (0–3) earned on this core.
    func stars(for core: DataCore) -> Int {
        let idx = core.id - 1
        return idx >= 0 && idx < save.campaignStars.count ? save.campaignStars[idx] : 0
    }

    /// Record a campaign attempt: always pay Credits for the decodes (shared
    /// economy → progress never fully stalls), track the per-core best score + best
    /// stars, and advance the campaign if this win cleared the next locked core.
    /// Returns Credits earned.
    @discardableResult
    func recordCore(_ core: DataCore, won: Bool, score: Int, stars: Int = 0, on date: Date) -> Int {
        let earned = salvaged(forScore: score)
        save.cyberdeck.credits += earned
        while save.campaignBests.count < core.id { save.campaignBests.append(0) }
        save.campaignBests[core.id - 1] = max(save.campaignBests[core.id - 1], score)
        while save.campaignStars.count < core.id { save.campaignStars.append(0) }
        save.campaignStars[core.id - 1] = max(save.campaignStars[core.id - 1], stars)
        if won && core.id == save.campaignProgress + 1 {
            save.campaignProgress = core.id
        }
        persist()
        return earned
    }

    /// Credits a final score awards, after the Salvage-Protocol bonus.
    private func salvaged(forScore score: Int) -> Int {
        let base = config.credits(forScore: score)
        let bonus = config.salvageBonusPerLevel * Double(save.cyberdeck.salvageLevel)
        return Int((Double(base) * (1 + bonus)).rounded())
    }

    /// Credits a given final score will award (for previewing on the HUD).
    func creditsForScore(_ score: Int) -> Int { salvaged(forScore: score) }

    func isHighScore(_ score: Int) -> Bool { save.isHighScore(score) }

    /// Record a finished session: pay credits once and update the leaderboard.
    /// `creditMultiplier` (>1 with endless run modifiers) boosts the Credits only — the
    /// raw `score` still goes to the leaderboard so the global board stays fair.
    /// Returns the credits awarded (for the game-over screen).
    @discardableResult
    func recordSession(score: Int, on date: Date, creditMultiplier: Double = 1) -> Int {
        let earned = Int((Double(salvaged(forScore: score)) * creditMultiplier).rounded())
        save.cyberdeck.credits += earned
        save.insertScore(score, on: date)
        persist()
        return earned
    }

    /// Record a finished PROTOCOL run: pays Credits (shared economy) but does NOT touch
    /// the Endless high-score list / leaderboard — PROTOCOL's score isn't comparable to
    /// Endless, so it must not pollute that board.
    @discardableResult
    func recordProtocolRun(score: Int) -> Int {
        let earned = salvaged(forScore: score)
        save.cyberdeck.credits += earned
        persist()
        return earned
    }

    // MARK: Daily challenge

    /// Today's best on the daily challenge (0 if the stored best is from another day).
    func dailyBest(forDay day: String) -> Int {
        save.dailyBestDay == day ? save.dailyBestScore : 0
    }

    /// The current Daily-Hack streak (consecutive days played), valid only relative to
    /// `today`/`yesterday`: today keeps it, yesterday means it's still alive, an older day
    /// means it has lapsed (shown as broken). The menu uses this for the streak chip.
    func dailyStreak(today: String, yesterday: String) -> Int {
        (save.dailyStreakDay == today || save.dailyStreakDay == yesterday) ? save.dailyStreak : 0
    }

    /// Record a finished daily run: pays Credits, updates the day's best, and advances the
    /// consecutive-day streak (once per day; +1 if yesterday was played, reset to 1 after a
    /// gap). `isHighScore` means "new daily best". Returns the streak in the outcome.
    @discardableResult
    func recordDaily(score: Int, day: String, yesterday: String) -> SessionOutcome {
        let earned = salvaged(forScore: score)
        save.cyberdeck.credits += earned
        let prev = dailyBest(forDay: day)
        let isBest = score > prev
        if isBest { save.dailyBestDay = day; save.dailyBestScore = score }
        // Streak: count once per day; consecutive if the last counted day was yesterday.
        if save.dailyStreakDay != day {
            save.dailyStreak = (save.dailyStreakDay == yesterday) ? save.dailyStreak + 1 : 1
            save.dailyStreakDay = day
        }
        persist()
        return SessionOutcome(creditsEarned: earned, isHighScore: isBest, dailyStreak: save.dailyStreak)
    }

    /// Build the Wordle-style shareable result text for a finished daily run.
    static func dailyShareText(day: String, score: Int, bestStreak: Int, fevers: Int, dayStreak: Int) -> String {
        let n = NumberFormatter(); n.numberStyle = .decimal
        let scoreStr = n.string(from: NSNumber(value: score)) ?? "\(score)"
        var lines = ["GRID_BREAKER ▦ Daily Hack · \(day)",
                     "◆ SCORE \(scoreStr)   🔥 ×\(bestStreak)   ⚡ \(fevers)"]
        if dayStreak > 1 { lines.append("📆 \(dayStreak)-day streak") }
        lines.append(GameStore.shareURL)
        return lines.joined(separator: "\n")
    }

    /// Public link for shares. Points at the marketing page (stable, redirects to the App
    /// Store); swap to the direct App Store URL once the numeric app ID is known.
    static let shareURL = "https://jimmyrentmeester.github.io/gridbreaker/"

    /// Attempt to buy one level of an upgrade. Returns true on success.
    @discardableResult
    func purchase(_ upgrade: CyberdeckUpgrade) -> Bool {
        let level = upgrade.currentLevel(in: save.cyberdeck)
        guard level < upgrade.maxLevel else { return false }
        let cost = upgrade.cost(atLevel: level)
        guard save.cyberdeck.credits >= cost else { return false }

        save.cyberdeck.credits -= cost
        switch upgrade {
        case .ram:            save.cyberdeck.ramLevel += 1
        case .decodeSpeed:    save.cyberdeck.decodeSpeedLevel += 1
        case .shield:         save.cyberdeck.shieldLevel += 1
        case .feverCapacitor: save.cyberdeck.feverLevel += 1
        case .salvage:        save.cyberdeck.salvageLevel += 1
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
