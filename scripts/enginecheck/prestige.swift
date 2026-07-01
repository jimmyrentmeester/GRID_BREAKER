import Foundation

// Standalone verification of the Prestige unlock rule (Cosmetics 2.0 — the
// earn-only cosmetics tied to campaign stars / completion / the daily streak).
// The rule is pure data in Core/Models/Campaign.swift; the UI sweep and the
// GameStore grants are thin plumbing around it.
//
// Run from the repo root:  scripts/enginecheck/run.sh prestige

var failures = 0
func check(_ cond: Bool, _ msg: String) {
    print((cond ? "✅ " : "❌ FAIL: ") + msg)
    if !cond { failures += 1 }
}

let maxStars = Campaign.count * 3

// MARK: thresholds — each requirement flips exactly at its boundary
check(!Prestige.stars(12).met(totalStars: 11, campaignProgress: 0, dailyStreak: 0), "11★ does not unlock .stars(12)")
check(Prestige.stars(12).met(totalStars: 12, campaignProgress: 0, dailyStreak: 0), "12★ unlocks .stars(12)")
check(!Prestige.stars(24).met(totalStars: 23, campaignProgress: 16, dailyStreak: 99), "23★ does not unlock .stars(24) (other progress is irrelevant)")
check(Prestige.stars(24).met(totalStars: 24, campaignProgress: 0, dailyStreak: 0), "24★ unlocks .stars(24)")

check(!Prestige.campaignComplete.met(totalStars: maxStars, campaignProgress: Campaign.count - 1, dailyStreak: 0),
      "\(Campaign.count - 1)/\(Campaign.count) cores does not unlock .campaignComplete")
check(Prestige.campaignComplete.met(totalStars: 0, campaignProgress: Campaign.count, dailyStreak: 0),
      "\(Campaign.count)/\(Campaign.count) cores unlocks .campaignComplete")

check(!Prestige.allStars.met(totalStars: maxStars - 1, campaignProgress: Campaign.count, dailyStreak: 0),
      "\(maxStars - 1)★ does not unlock .allStars")
check(Prestige.allStars.met(totalStars: maxStars, campaignProgress: 0, dailyStreak: 0),
      "\(maxStars)★ unlocks .allStars")

check(!Prestige.dailyStreak(7).met(totalStars: 0, campaignProgress: 0, dailyStreak: 6), "6-day streak does not unlock .dailyStreak(7)")
check(Prestige.dailyStreak(7).met(totalStars: 0, campaignProgress: 0, dailyStreak: 7), "7-day streak unlocks .dailyStreak(7)")

// MARK: labels — transparent goals + clamped progress chips
check(Prestige.stars(24).goal == "EARN 24★ IN CAMPAIGN", "goal label for .stars")
check(Prestige.allStars.goal == "EARN ALL \(maxStars)★", "goal label for .allStars")
check(Prestige.campaignComplete.goal == "CRACK ALL \(Campaign.count) CORES", "goal label for .campaignComplete")
check(Prestige.dailyStreak(7).goal == "7-DAY DAILY STREAK", "goal label for .dailyStreak")

check(Prestige.stars(24).progressLabel(totalStars: 18, campaignProgress: 0, dailyStreak: 0) == "18/24★", "progress 18/24★")
check(Prestige.stars(24).progressLabel(totalStars: 99, campaignProgress: 0, dailyStreak: 0) == "24/24★", "progress clamps at the goal")
check(Prestige.campaignComplete.progressLabel(totalStars: 0, campaignProgress: 5, dailyStreak: 0) == "5/\(Campaign.count)", "progress 5/\(Campaign.count) cores")
check(Prestige.dailyStreak(7).progressLabel(totalStars: 0, campaignProgress: 0, dailyStreak: 3) == "3/7 DAYS", "progress 3/7 days")

// MARK: the star economy — the ladder can actually pay out every threshold
check(maxStars == 48, "16 cores × 3★ = 48 obtainable stars (thresholds 12/24/48 all reachable)")

print(failures == 0 ? "\n🎉 ALL PRESTIGE CHECKS PASSED" : "\n💥 \(failures) CHECK(S) FAILED")
exit(failures == 0 ? 0 : 1)
