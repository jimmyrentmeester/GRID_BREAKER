import Foundation
import GameKit
import UIKit

// MARK: - Game Center IDs (must match App Store Connect exactly)
//
// Configure these under App Store Connect → GRID_BREAKER → Game Center before
// they will accept submissions. Until then, reporting fails silently — by
// design, Game Center is *report-only* and can never affect a session.

/// Leaderboards. `endless` is classic (all-time); `daily` should be created as a
/// recurring leaderboard (daily reset) so it mirrors the in-game daily challenge.
enum GCLeaderboard: String {
    case endless = "nl.gridbreaker.lb.endless"
    case daily   = "nl.gridbreaker.lb.daily"
}

/// Achievements. All earnable through normal play — never purchasable (see
/// docs/MONETIZATION.md: real money must not touch the gameplay economy).
enum GCAchievement: String, CaseIterable {
    // Run achievements (endless / daily / campaign — never Flow).
    case firstFever   = "nl.gridbreaker.ach.firstfever"    // trigger Fever Mode once
    case feverLoop    = "nl.gridbreaker.ach.feverloop"     // 3 fevers in one run
    case cleanStreak  = "nl.gridbreaker.ach.streak25"      // clean streak of 25
    case failsafe     = "nl.gridbreaker.ach.failsafe"      // shield absorbs a mistake
    case toolbelt     = "nl.gridbreaker.ach.toolbelt"      // collect a power-up
    case gridExpanded = "nl.gridbreaker.ach.grid4x4"       // unlock the 4×4 grid
    // Score landmarks (endless / daily only — campaign targets are hand-tuned).
    case score100     = "nl.gridbreaker.ach.score100"
    case score250     = "nl.gridbreaker.ach.score250"
    case score500     = "nl.gridbreaker.ach.score500"
    // Meta achievements (synced from persisted progress, idempotent).
    case firstCore    = "nl.gridbreaker.ach.core1"         // crack core 1
    case coreDepth    = "nl.gridbreaker.ach.core5"         // crack core 5
    case allCores     = "nl.gridbreaker.ach.core10"        // crack The Monolith
    case maxedTrack   = "nl.gridbreaker.ach.maxtrack"      // max any Cyberdeck track
}

/// Which ruleset a finished run was played under (for routing reports).
enum GCRunMode {
    case endless, daily, campaign, protocolMode
}

// MARK: - Diagnostics

/// Lightweight console trace for Game Center wiring (Debug only). Game Center is
/// report-only and fails silently by design in Release; this makes auth/submit
/// outcomes visible while debugging "scores don't show up" — without changing any
/// shipping behavior. View it in the Xcode console (or Console.app for a device run).
@inline(__always)
func gcLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print("🎮 [GameCenter] \(message())")
    #endif
}

// MARK: - Service

/// Report-only bridge to Game Center. The engine stays the sole authority
/// (ground-truth Part 1.1): this type *observes* finished snapshots and engine
/// events and forwards them — it never feeds anything back into a session, and
/// every call is a no-op when the player declined Game Center.
///
/// Auth is optional by design: the local save (`GameStore`) remains the offline
/// source of truth; Game Center only mirrors results for global boards/badges.
@MainActor
@Observable
final class GameCenterService {
    static let shared = GameCenterService()
    private init() {}

    private(set) var isAuthenticated = false
    /// Achievement IDs already reported this launch (cheap dedupe; Game Center
    /// itself also ignores re-reports of completed achievements).
    private var reportedThisLaunch: Set<String> = []
    /// Whether the menu hub is on screen (drives the floating access point).
    var menuVisible = false { didSet { updateAccessPoint() } }

    // MARK: Authentication

    /// Kick off Game Center auth. Safe to call once at launch: presents Apple's
    /// sheet if needed; if the player declines (or the account is restricted),
    /// the game continues untouched and every report below becomes a no-op.
    func authenticate(onAuthenticated: (@MainActor () -> Void)? = nil) {
        GKLocalPlayer.local.authenticateHandler = { viewController, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error { gcLog("Auth error: \(error.localizedDescription)") }
                if let viewController {
                    Self.present(viewController)
                    return
                }
                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                gcLog(self.isAuthenticated
                      ? "Authenticated as \(GKLocalPlayer.local.alias)"
                      : "Not authenticated (player declined or account restricted) — reports are no-ops")
                self.updateAccessPoint()
                if self.isAuthenticated {
                    self.verifyLeaderboards()   // surfaces missing/misnamed boards (Debug)
                    onAuthenticated?()
                }
            }
        }
    }

    /// Debug diagnostic: ask Game Center which of our leaderboard IDs actually exist
    /// in App Store Connect. The #1 cause of "leaderboards don't work in production"
    /// is the boards not being created — or not yet live — under the *exact* IDs the
    /// code uses. This surfaces that in the console instead of failing silently.
    /// No-op in Release (the body is Debug-only).
    func verifyLeaderboards() {
        #if DEBUG
        let ids = [GCLeaderboard.endless.rawValue, GCLeaderboard.daily.rawValue]
        Task {
            do {
                let boards = try await GKLeaderboard.loadLeaderboards(IDs: ids)
                let found = Set(boards.map(\.baseLeaderboardID))
                for id in ids {
                    gcLog(found.contains(id)
                          ? "Leaderboard OK: \(id)"
                          : "Leaderboard MISSING in App Store Connect: \(id)")
                }
            } catch {
                gcLog("Leaderboard lookup failed: \(error.localizedDescription)")
            }
        }
        #endif
    }

    /// Present Apple's auth sheet over whatever is frontmost.
    private static func present(_ viewController: UIViewController) {
        let root = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first
        var top = root
        while let presented = top?.presentedViewController { top = presented }
        top?.present(viewController, animated: true)
    }

    /// Apple's floating Game Center widget — menu hub only, never in a session
    /// (nothing may overlay the grid mid-run).
    private func updateAccessPoint() {
        GKAccessPoint.shared.location = .topTrailing
        GKAccessPoint.shared.showHighlights = false
        GKAccessPoint.shared.isActive = isAuthenticated && menuVisible
    }

    // MARK: Reporting (all fire-and-forget, all gated on auth)

    /// Submit a final score to a leaderboard.
    func submit(score: Int, to board: GCLeaderboard) {
        guard isAuthenticated, score > 0 else { return }
        Task {
            do {
                try await GKLeaderboard.submitScore(score, context: 0,
                                                    player: GKLocalPlayer.local,
                                                    leaderboardIDs: [board.rawValue])
                gcLog("Submitted \(score) → \(board.rawValue)")
            } catch {
                gcLog("Submit FAILED \(score) → \(board.rawValue): \(error.localizedDescription)")
            }
        }
    }

    /// Re-submit the player's existing local bests right after auth, so scores earned
    /// before Game Center was reachable (player declined earlier, was offline, or the
    /// boards only just went live) show up retroactively. Game Center keeps only a
    /// player's *highest* score per board, so re-submitting an already-present score is
    /// harmless. `dailyBest` should already be 0 unless it belongs to today's recurring
    /// period (GameStore filters it), so it's only pushed when still relevant.
    func submitBacklog(endlessBest: Int, dailyBest: Int) {
        guard isAuthenticated else { return }
        if endlessBest > 0 { gcLog("Backlog endless best \(endlessBest)"); submit(score: endlessBest, to: .endless) }
        if dailyBest > 0 { gcLog("Backlog daily best \(dailyBest)"); submit(score: dailyBest, to: .daily) }
    }

    /// Mark an achievement 100% complete (one banner, then permanently done).
    func report(_ achievement: GCAchievement) {
        guard isAuthenticated, !reportedThisLaunch.contains(achievement.rawValue) else { return }
        reportedThisLaunch.insert(achievement.rawValue)
        let a = GKAchievement(identifier: achievement.rawValue)
        a.percentComplete = 100
        a.showsCompletionBanner = true
        Task {
            do { try await GKAchievement.report([a]); gcLog("Reported achievement \(achievement.rawValue)") }
            catch { gcLog("Achievement report FAILED \(achievement.rawValue): \(error.localizedDescription)") }
        }
    }

    /// End-of-run funnel: called exactly once per finished session, right where
    /// the score is persisted (GameView's game-over hook), with the engine's
    /// final snapshot — the same verified data the recap screen renders.
    func reportRunEnd(_ s: SessionSnapshot, mode: GCRunMode) {
        switch mode {
        case .endless: submit(score: s.score, to: .endless)
        case .daily:   submit(score: s.score, to: .daily)
        case .campaign, .protocolMode: break    // campaign/PROTOCOL rank ≠ comparable score
        }
        // Run achievements still earn in PROTOCOL (it's a real challenge run).
        if s.feversTriggered >= 1 { report(.firstFever) }
        if s.feversTriggered >= 3 { report(.feverLoop) }
        if s.bestCleanStreak >= 25 { report(.cleanStreak) }
        if s.gridSize == .fourByFour { report(.gridExpanded) }
        if mode != .campaign && mode != .protocolMode {   // score landmarks: endless/daily only
            if s.score >= 100 { report(.score100) }
            if s.score >= 250 { report(.score250) }
            if s.score >= 500 { report(.score500) }
        }
    }

    /// Sync meta achievements from persisted progress. Idempotent — call on
    /// returning to the menu; covers progress earned before auth or offline.
    func syncMeta(campaignProgress: Int, deck: Cyberdeck) {
        guard isAuthenticated else { return }
        if campaignProgress >= 1 { report(.firstCore) }
        if campaignProgress >= 5 { report(.coreDepth) }
        if campaignProgress >= Campaign.count { report(.allCores) }
        if CyberdeckUpgrade.allCases.contains(where: { $0.currentLevel(in: deck) >= $0.maxLevel }) {
            report(.maxedTrack)
        }
    }
}
