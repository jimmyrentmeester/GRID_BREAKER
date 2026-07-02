# PROTOCOL — new game mode (replaces Flow)

Status: **IN PROGRESS** (Run #88+, both mechanics built — phase 4 balance left). Maintainer-chosen design (post-launch): Flow (chill,
no-fail) is replaced by an *objective-driven* mode that gives the two community-requested
mechanics a home. Community issues: DAEMON SET (#3), DMZ PURGE (#4).

## Concept
PROTOCOL is a focused, **objective-driven** mode layered on a light daemon stream. Instead of
pure reflex (Endless) or calm (old Flow), the run feeds you a sequence of **hack objectives**
that alternate between the two mechanics. It has a real fail state (the RAM clock + DMZ
overrun), so it's a *challenge* mode, not a chill one.

Engine stays the authority (ground-truth Part 1.1): all objective state, ordering, and
resolution live in `GridEngine`; the view only renders snapshots + dresses `GameEvent`s.

## The two objectives (alternating)
### DAEMON SET (issue #3)
- A short ordered chain of N daemons (N = 2…4) that must be tapped **in order**.
- Order shown by filled pips on each tile (1 → N).
- Tapping the correct next one advances the set; tapping a later one (out of order) is a miss
  (no advance; standard miss penalty) — the set is NOT failed, you just have to hit the right one.
- Completing the set: a one-time **×4 multiplier on the next decode** (`daemonSetReward`).
  - **Fever duration:** a set-triggered Fever lasts `setFeverDurationMult × base`. In PROTOCOL
    this is **×1** (base window) — sets are the *core loop* here, and the old ×4 chained
    near-permanent Fever (59% uptime under perfect play; a 16 s continuous block that read as
    "Fever never depletes", fixed 2026-07-02). The ×4 climactic set-Fever lives on for
    **campaign bosses**, where sets are rare. See `enginecheck/feverdur.swift`.
- Deterministic: the set's cells + order are chosen by the seeded RNG at spawn.

### DMZ PURGE (issue #4)
- An outlined zone of ≥ 1×2 cells, spawned **full** of hostile `intrusion` nodes.
- While a DMZ is active, the rest of the grid slowly fills with intrusion nodes (a creeping
  overrun). If the **whole grid** fills → game over.
- Clearing every cell in the DMZ dismisses it (and stops the overrun) → back to the daemon
  stream until the next objective.
- Intrusion nodes are tappable targets (one tap), distinct visual (hostile red/orange).

## Alternation
A PROTOCOL run cycles: light daemon stream → DAEMON SET → daemon stream → DMZ PURGE → … The
gap and objective difficulty ramp with score (like the other modes' difficulty bias).

## Build phases (each its own commit, verified)
1. **Skeleton** ✅ (Run #88) — PROTOCOL exists, replaces Flow in the menu + routing, runs a
   challenging non-chill ruleset (RAM clock + fail). `GameConfig.protocolMode()`, `RootView`
   routing, menu tile FLOW→PROTOCOL, Game Center mode handling.
2. **DAEMON SET** ✅ (Run #89) — engine model (`GridNode.setOrder/setSize`, seeded set spawner on a
   gap timer, ordered tap resolution, ×4-next-decode + ×4-Fever-duration reward), UI (numbered
   set sprite with order pips), completion/wrong-order juice + toast. Set nodes don't expire; no
   new sets spawn mid-Fever. Verified in the simulator (sets spawn + render). Tap resolution +
   ×4 reward still to confirm on device.
3. **DMZ PURGE** ✅ (Run #93) — engine: `NodeType.intrusion` (persistent, one-tap), a zone model
   (`dmzZone` = a contiguous block of free cells spawned full of intrusion), an overrun creep timer
   (`dmzOverrunInterval` — fills a random cell *outside* the zone; no room left → game over
   `.dmzOverrun`), defensive clears (`clearIntrusion`, flat score + small RAM, kept out of the
   combo/fever system), and a full purge that sweeps the overrun + grants RAM relief. The normal
   daemon stream pauses while a DMZ is active. A minimal objective **scheduler** (`objectiveCursor`
   over the enabled objectives) now alternates DAEMON SET ↔ DMZ. UI: hostile red intrusion sprite,
   dashed red zone outline (stays after a cell is cleared → shows purge progress), spawn/clear/
   overrun/purge juice (toast + haptics + audio), `DMZ OVERRUN` game-over headline. Verified:
   18/18 deterministic checks (`scripts/enginecheck/dmz.swift`) + Debug build succeeds.
4. **Difficulty ramp** ✅ (Run #94) — four score-scaled `GameConfig` accessors (`objectiveGap`,
   `dmzOverrunPace`, `daemonSetSizeRange`, `dmzSizeRange`), each with exponential compression toward
   a fairness floor. Engine call-sites wired. Verified: 48/48 deterministic checks (15 daemonset +
   18 dmz + 15 ramp) + DEBUG BUILD SUCCEEDED. **Remaining: on-device balance/feel pass + merge.**

## Notes / decisions
- Flow's `chill` implementation is left in place but unreachable from the menu (removing its
  ~36 call sites is a separate, risk-free cleanup). PROTOCOL never sets `chill`.
- No leaderboard for PROTOCOL initially (its score isn't comparable to Endless); achievements
  may come later. Reported as its own `GCRunMode` that submits no score.
