# Run prompt: one task, then stop

You're building GRID_BREAKER (a neon-cyberpunk whack-a-mole reflex game, iOS
SwiftUI). Follow this cycle strictly. One task per run.

## Hard rules (every run)
- Use **Sonnet**, not Opus. Budget-aware.
- Max ~20 min effective work, then wrap up.
- Read narrowly. No broad repo scans. Hub = `CLAUDE.md`.
- `GAME_GROUND_TRUTH.md` Parts 0–7 are **binding**. Part 8 (AI) is **voided** (no LLM).
- The **engine is the authority** — never put score/RAM/spawn/hit-resolution logic
  in the view. Mechanics live in `Core/`. (Ground-truth Part 1.1.)
- Skill `game-feel-and-juice` — use on ANY run touching animation, feedback, impact,
  particles, haptics, "how it feels". Every flourish must trace to a real engine event.
- Per decision, briefly weigh 1-2 expert lenses (engineer / game-feel / QA / audio);
  log non-trivial choices in `docs/DECISIONS.md`. No long dialogue.

## Steps
0. **Resume check (BEFORE anything — a prior run may have stopped mid-task):**
   ```
   git status --porcelain
   tail -8 docs/LOG.md
   ```
   `docs/LOG.md` is the ONLY source of truth for "is a run done". Never infer
   completion from commit messages. Only an implementation LOG line (with file names
   / what was built) counts as proof.
   - **Dirty tree** → prior run aborted mid-task. Finish that task from current state
     (read top ROADMAP item); if incoherent → QUESTIONS.md + `notify_blocked` + stop.
     Do NOT `git checkout`/`restore` yourself.
   - **Clean tree** → if the top ROADMAP item has no implementation LOG line, do it.
1. **Context**: `tail -50 docs/LOG.md`, `cat docs/ROADMAP.md`, check `docs/QUESTIONS.md`.
2. **Select ONE task**: the top open item in ROADMAP.md. No more.
3. **Execute**: one feature / one bug / one refactor.
4. **Build AND install AND launch** on a real booted simulator — not just compile
   (compile-green ≠ works). Default device: **iPhone 17 (iOS 26.5)**.
   ```
   SIM_ID=$(xcrun simctl list devices booted | awk -F '[()]' '/iPhone/ {print $2; exit}')
   if [ -z "$SIM_ID" ]; then
     SIM_ID=$(xcrun simctl list devices | awk -F '[()]' '/iPhone 17 \(iOS 26.5\)/ {print $2; exit}')
     if [ -z "$SIM_ID" ]; then
       SIM_ID=$(xcrun simctl create "iPhone 17 (iOS 26.5)" \
         "com.apple.CoreSimulator.SimDeviceType.iPhone-17" \
         "com.apple.CoreSimulator.SimRuntime.iOS-26-5")
     fi
     xcrun simctl boot "$SIM_ID"; open -a Simulator; sleep 4
   fi
   xcodebuild -project App/GRID_BREAKER.xcodeproj -scheme GRID_BREAKER \
     -destination "platform=iOS Simulator,id=$SIM_ID" build
   APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/GRID_BREAKER-*/Build/Products/Debug-iphonesimulator -name "GRID_BREAKER.app" -type d | head -1)
   xcrun simctl install booted "$APP_PATH"
   xcrun simctl launch booted nl.gridbreaker.app
   ```
   Screenshot to verify gameplay/layout/feel, not just the build.
5. **Green?** → `git add -A && git commit -m "Feature (engine): <desc>"` (type-prefixed,
   imperative, NO `Run #N:` prefix, no secrets).
6. **Update docs**: `docs/LOG.md` (append, dated, with file evidence), `docs/UPDATES.md`,
   `docs/ROADMAP.md` (done item → archived, next task on top), `docs/DECISIONS.md` (only
   if a non-trivial choice was made).
7. **Notify**: `source scripts/notify.sh && notify_update "GRID_BREAKER" "<one line>"`.
8. **STOP**. Do not continue to the next task.

## On red / blocked
1. Write the problem in `docs/QUESTIONS.md` under OPEN, numbered.
2. Update `docs/UPDATES.md` status ❌/⚠️.
3. `source scripts/notify.sh && notify_blocked "<reason>"`.
4. No commit of half features. STOP.

## When status ⚠️ (input needed)
- A design/tech choice with lasting impact, or anything needing money / an Apple
  Developer account, or 2 consecutive runs blocked on the same thing.
- Do NOT ask for small implementation/naming/color choices — decide and log.

Begin.
