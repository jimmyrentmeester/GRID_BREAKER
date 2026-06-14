# Game Ground Truth — distilled build rules for the next game project

> **What this is.** A reusable "ground truth": the hard-won rules, architecture
> choices, cross-platform lessons and QA approach distilled from the **Eldor /
> AI Dungeon Master** project, packaged so you can feed it as *project
> instructions* for a **new game** (with or without AI).
>
> **How to use it.**
> 1. Paste this entire document as the project/system instruction for the agent
>    building the new game.
> 2. Fill in **Part 10 — The New-Game Brief**: that is where *you* describe the
>    specific game. Everything before Part 10 is the general knowledge that
>    governs *how* the game is built, regardless of which game it is.
> 3. The agent reads Parts 0–9 as binding rules and Part 10 as the assignment.
>
> **Reading note for the agent.** Parts 0–7 are **universal** (they apply to games
> *without* AI too). Part 8 is an **optional chapter** that only applies if the game
> uses an LLM/AI — skip it for classic games. Part 9 is the **reference stack** (a
> concrete Eldor example); use it as a blueprint, not a mandate. Rules in **BOLD**
> are non-negotiable unless the brief explicitly overrides them; every rule was
> learned from real production pain, not theory.
>
> **Companion skills (optional, auto-loading).** Three reusable skills hold the
> *deep* playbooks behind this doc and trigger automatically during the relevant
> work: **`game-feel-and-juice`** (Part 2), **`cross-platform-game-porting`**
> (Part 4 + a Skip transpilation pitfall catalog), and **`llm-game-architecture`**
> (Part 8). This document stays the always-on constitution; the skills are the
> on-demand detail. If they're not installed, this doc is fully self-contained.
>
> **Shipping & business (Appendices A–E).** Parts 0–9 cover *building* the game.
> Everything *after* it's built — App Store submission, business/tax/legal compliance,
> ethical monetization, code-generated art & marketing, and QA for a deterministic
> real-time game — is distilled in **Appendices A–E** from the **GRID_BREAKER**
> project (a native iOS reflex arcade shipped to the App Store solo at €0). Universal
> for any **native app-store release**; skip for web-only or pre-release work.
> GRID_BREAKER is also added as a second reference stack in Part 9 — the
> single-platform counterpoint to Eldor's four-shell build.

---

## Part 0 — Operating principles (how you build)

This is about the build process itself. Ignore it and you will repeat our most
expensive mistakes.

- **Build in vertical slices, not in layers.** One scoped, end-to-end working
  feature per session (data → logic → UI → visible result). Not "all models first,
  then all views." Each slice ends with something you can *watch run*.
- **"Compiles/transpiles green" ≠ "works".** A passing build proves nothing about
  behavior. **Always verify the real result** — run it, screenshot it, play a short
  session. Several runtime bugs (scroll gestures, z-index occlusion, layout
  overflow) were invisible at build time and only visible on screen.
- **One source of truth for state.** Decide early who is the authority over game
  state (the engine/server), and let nothing else mutate it. The presentation
  layer (view, client, AI narration) may **never** invent or change the truth. See
  Part 1.
- **The spec is reusable, the code is not.** Data models, rules, deterministic math,
  prompt/tool schemas and art "recipes" survive a rewrite to another stack; UI views
  and platform services do not. Document the spec explicitly → a later port becomes
  tractable instead of archaeology.
- **Document as you build.** One **hub document** (like this / a `CLAUDE.md`) with
  conventions + design decisions + pitfalls, and **deeper per-domain docs** loaded
  only on demand. Plus a **living PROGRESS** (✅ done / 🚧 in progress / 📋 roadmap /
  🐛 bugs). Update both at the end of every session.
- **Read narrowly, not the whole codebase.** Hub doc + the relevant domain doc + the
  files in play. Context is a scarce resource.
- **Commit at logical points.** Imperative, type-prefixed messages (`Fix (web): …`,
  `Feature (engine): …`), never opaque `Run #N:` prefixes, never secrets. A commit =
  one finished, verified thought.
- **Split when context gets tight; don't push through.** A half-finished marathon
  costs more than two clean slices.

---

## Part 1 — Game design: the hard rules (universal)

These apply to any game with state, progression and rules.

### 1.1 The authority principle (the hardest rule)
**All mechanical outcomes — dice, damage, stat changes, loot, economy — are
computed deterministically by the authority (engine/server), never by the
presentation layer or an AI.** The narration/UI only *reports* what the engine
returned.

- Prevents cheating, hallucination, desync and client-side exploits.
- Holds equally for multiplayer (server is authority, client is dumb), singleplayer
  (engine is authority, view is dumb) and AI games (code decides, LLM narrates).
- **Mutations go through a narrow, explicit set of commands/tools** the authority
  applies — not via free-form writes scattered across the UI.

### 1.2 Player agency without cheating
The player must feel that *their* choice made the difference — without being able to
choose the outcome.
- **The player triggers; the system resolves.** (In Eldor: the player taps "roll
  d20", the app rolls the value — anti-cheat.) Show the cause→effect chain
  explicitly: choice → roll → outcome → narrative consequence.
- Give choices **character**: subtly tint aggressive, social, cautious options
  differently — a hint, never a spoiler.

### 1.3 World/fact authority
Decide explicitly **who may assert facts about the world**. In Eldor: only the DM
describes what *is*; the player only states *intent*, not world facts or loot ("I
see a ring lying there and pick it up" → refused). In any game with open input or
UGC: separate *player intent* from *world truth*.

### 1.4 Visible growth & feedback loops
- **Always show progress without the player having to re-read anything** —
  HP/level/XP/loot/quest on screen, reactive.
- **Confirm every state mutation visibly** the moment it happens (a pulse, toast,
  floating number), not only in text.
- **Celebrate growth, don't report it.** A level-up is a *moment* (dim the rest,
  flourish, particles, haptic, a choice with a preview of its effect) — not a grey
  line "You are now level 3." First kill, boss, rare loot, new area: a short
  in-world flourish.

### 1.5 Direction & goals
An open game without direction feels like "now what?". **Keep the "why am I here"
explicit.**
- An active goal/quest with **objectives** for tangible sub-progress ("1/3").
- **There MUST be a goal at the start** — no empty opening.
- Mirror active goals back to the authority (and, for AI, into the prompt) as a
  source of truth so the game steers toward them consistently.

### 1.6 Reward discipline (no double payout)
- Rewards are **deterministic** and paid out **in one place, once** (e.g. the app
  pays the quest reward on `complete_quest`). Make sure no second path (the AI, a
  view, another tool) pays the same reward again. We shipped double-XP because two
  paths celebrated the same thing.

### 1.7 Difficulty & balance
- Scale difficulty with the action, not with a "safe middle". Give an explicit
  ladder (e.g. D&D DCs 5/10/15/18/20/25/30) and **force variation**.
- **Not every trivial action needs a check/obstacle.** Trivial = no roll.
- **Anti-anchor lesson (crucial for both AI and procedural systems):** if you push a
  system (or model) away from a value by repeatedly *naming* it ("never use 12"),
  you make it more salient and you *get* 12. Frame positively, don't name the value
  to avoid, and don't put a "typical/default" band in the ladder. (This cost us a
  full debug session.)

### 1.8 Localization is first-class — at the injection boundary
Localize **at the point where data enters a subsystem**, not only at display. We
leaked Dutch talent names ("Krachtige Houw") into an English game because the
*prompt* received the raw canonical name while only the UI display was translated.
Rule: every string that enters another subsystem (AI, network, another player) goes
in the receiver's language/locale — not the canonical storage form.

---

## Part 2 — Game feel & "juice" (universal)

A game must feel **tactile, tense and alive** — not a UI with numbers. Mechanics
stay deterministic (Part 1); this is purely about presentation.

### 2.1 The five pillars — test every feature against these
1. **Make agency felt** — the player feels their choice mattered (cause→effect
   visible).
2. **Tension before reveal** — never dump a result instantly; a short build-up
   (0.4–0.9 s) makes an outcome exciting.
3. **The world feels alive** — atmosphere, scene and "thinking" cues sell that
   something is behind it (typing indicator, mood transition, drifting ambient
   particles, ambient audio).
4. **Visible growth** — see Part 1.4.
5. **Diegetic calm** — a consistent, calm rest state; juice is fierce only on the
   *moment*.

Test: does the proposal strengthen at least one pillar without breaking another? If
not: trim or drop it.

### 2.2 Juice recipe catalog (asset-free where possible)
- **Floating numbers** — damage/heal pops on the target and drifts up while fading;
  crit = larger + different color + slight wobble. Fed from a real state event,
  never "guessed".
- **Hit-stop** — freeze ~70–110 ms before the shake/flash on a heavy hit; gives
  weight.
- **Particles** — spark burst on crit, rising shimmer on heal. Keep it small (≤ ~30
  particles), reuse one burst component everywhere (combat crit, d20 crit,
  level-up).
- **HP bar with a ghost layer** — a slow "ghost" (old HP, easeOut ~0.6 s) behind the
  live layer (new HP, easeOut 0.3 s); the receding chunk sells the hit.
- **Button/choice feedback** — every tap a micro-response (0.06 s scale to 0.96 +
  spring back); a chosen option may briefly light up before it disappears.
- **Dice drama** — button → short tumble (cycling digits, decelerating) → landing
  with haptic → crit/fumble treatment. **Never rest on a misleading value** (a d20
  showing "20" before the roll reads as already-rolled → show a neutral "?").
- **Telegraphing** — show enemy intent (⚔ attack / ✋ defends / ✦ casts) so the
  player has something to decide on instead of trading blind.
- **Loot reveal** — rarity has weight: rarity color drives edge-glow + intro;
  legendary revealed slower + particles.
- **Atmosphere layer** — a subtle, mood-tinted background (gradient + vignette +
  drifting particles) behind the UI that cross-fades on mood change.

### 2.3 Motion & timing
- Reactions/impact: `easeOut 0.3–0.5s` or a spring (`response 0.16–0.3`,
  `damping 0.45–0.7`). Atmosphere/transitions: `easeInOut 0.6–0.9s`.
- **Never linear** for UI motion. **Never > 1 s** for feedback (atmosphere may be
  longer). Animations may **never block input longer than ~1 s** and must be
  **skippable**.

### 2.4 Restraint & accessibility
- **Calm at rest, fierce on the moment.** No permanent glow/animation (it fatigues).
- One dominant motion per moment; the rest supports subtly.
- **Respect `prefers-reduced-motion`** (snap instead of animate, hide flash/
  particles). Guard contrast (forced dark mode is a classic source of unreadable
  buttons — always use theme tokens with explicit color, test contrast). Text is
  king: overlays/particles never over readable text.

### 2.5 Anti-patterns
- Putting mechanics in the view/prompt (they belong in the engine).
- Juice that masks latency but blocks input.
- Over-animating (everything at once = nothing stands out).
- Feedback without a source link (every flourish must trace to a real state event,
  else it reads as noise).
- Breaking the fiction/illusion (raw error messages, JSON, or mechanics jargon shown
  to the player — catch and reframe in-world or in a separate non-diegetic strip).

---

## Part 3 — Architecture (universal principles)

### 3.1 Layering: shared core vs. platform shell
Split the game into two clear halves:

- **Shared core (platform-agnostic, maximally reusable):**
  - *Models* — pure value types / data (serializable), no UI, no I/O.
  - *Engine* — deterministic rules & math (combat, dice, progression, economy), pure
    functions where possible.
  - *Provider/seam abstractions* — interfaces to the outside world (network, LLM,
    storage) so implementations are swappable *and* mockable.
  - *Orchestration* — the loop that drives input → engine → state mutation → output.
- **Platform shell (per target, not reusable):**
  - UI/views, platform services (storage, keychain, audio, haptics, network impl).

> The more correct logic lives in the shared core, the less **parity drift** between
> platforms. Nearly every parity bug we hit arose where logic was *not* shared, or
> data was *not* localized at the boundary.

### 3.2 One source of truth + unidirectional state
- State lives in one place; UI is a *derivation* of it. Mutations go through explicit
  commands/actions the authority applies (Part 1.1). No scattered writes.
- Strict MVVM / unidirectional flow: **views contain no game logic**.

### 3.3 Back-compatible persistence
- Persistent models evolve **without breaking old saves**: defaults for new fields,
  tolerant decode. **After every model change, test that an old save still loads.** A
  save crash on update is unforgivable.

### 3.4 Provider/seam abstraction (key to testability AND portability)
- Put an interface in front of every external dependency (LLM, network, storage,
  TTS). It buys: (a) swappable backends, (b) a **deterministic mock implementation**
  for free, fast, repeatable tests (see Part 5) — the highest-ROI investment in the
  whole project.

### 3.5 Organization & secrets
- **Group by feature, not by type** — ViewModels with their feature, pure models
  central.
- **Never put secrets in code/repo/UserDefaults.** Native: secure storage
  (Keychain/Keystore). Web: a key **cannot** live safely in the browser → backend/
  proxy (see Part 4.2). `.gitignore` keystores / `.env` / secrets.

---

## Part 4 — Cross-platform & portability

### 4.1 Choose deliberately: shared-Swift vs. full rewrite
| Route | Targets | Rewrite | Web? | Note |
|---|---|---|---|---|
| **Skip (skip.tools)** | iOS + Android | Small (keep Swift/SwiftUI) | ❌ | Least work, but only adds Android; no web/desktop. |
| **Flutter** | iOS/Android/web/desktop | Full (Dart) | ✅ mature | Widest coverage in one rewrite. |
| **Compose Multiplatform** | Android/iOS/desktop/web | Full (Kotlin) | ⚠️ web Beta | "Shared logic, native UI". |
| **Web-first (TS)** + shells (Tauri/Capacitor) | web → everything | Full (TS) | ✅ best | Web as the main product; needs a backend regardless. |

Decide this **early** — it shapes the whole stack. Only Skip keeps Swift; the rest is
a rewrite of UI + services (you reuse the *spec*, Part 0).

### 4.2 Web forces a backend (the others don't)
An API key in browser JS is readable by anyone, and CORS blocks direct calls. **A web
game with a paid/external API needs a backend proxy** (holds/forwards the key, handles
streaming + CORS). Native (iOS/Android/desktop) keeps the key locally and does not
need this. Plan this infra + cost the moment "web" is in the brief.

### 4.3 Parity discipline
- **Share the logic, not just the intent.** One set of rules in the shared core → no
  "iOS heals on level-up, web doesn't" divergence (a real bug we had).
- **Localize at the injection boundary** (Part 1.8).
- For every shared behavior change: mirror it across all shells, or better, lift it
  into the shared core so mirroring becomes unnecessary.

### 4.4 Transpilation/portability — survival rules
"Transpiles green ≠ works" — **verify on the real device** (scroll gestures,
bottom-sheets, layout caps and z-index were invisible at build time). Generic rules
distilled from ~47 concrete transpilation pitfalls:

- **Be explicit for the target language's type inference.** Float literals, generic
  args on collections (`Set<String>`, not `Set`), Double promotion of Int literals
  (`min(1.0, …)`, not `min(1, …)`), explicit closure parameters (`{ item in item.x }`
  instead of `{ $0.x }`) when the outer type is complex.
- **Avoid over-magic language constructs** that port poorly: custom operators (`+` →
  `.adding(...)`), `WritableKeyPath` subscript assignment (→ enum + switch), tuple
  destructuring with type annotation, KeyPath `id:` in lists (→ a real `Identifiable`
  struct).
- **Name clashes with the target language** (a `Character` type clashing with Kotlin's
  `Char`) → rename (→ `Hero`).
- **Platform APIs behind guards** (`#if`): audio session, haptics, regex,
  streaming-bytes APIs, not-everywhere modifiers.
- **Nested scroll containers and bottom-sheets** behave differently per platform;
  full-screen view swaps and manual row layouts are safer than lazy grids inside
  scroll views.
- **Resources via the module bundle**, not the app bundle.

> Keep a **living pitfall catalog** (like our 47): every pitfall you know upfront =
> one rebuild cycle you don't pay for. (The full Skip catalog lives in the Eldor
> reference-stack docs.)

### 4.5 A phased port = milestones with proof
Don't port big-bang. Split into milestones (M1…Mn) where **each milestone ends with a
running artifact + screenshot as proof.** Explicitly distinguish *verified-by-
construction* (built but not run live, e.g. blocked by an API restriction) from
*live-verified*. That way one hiccup doesn't block the whole port.

---

## Part 5 — Testing, QA & verification

### 5.1 The mock / deterministic backend (highest ROI in the project)
Build early a **network-free, deterministic implementation** of your
external-dependency seam (LLM, server, RNG source). In Eldor: a `MockProvider` that
drives the entire engine/UI flow (opening, choices, combat, quests, XP/loot,
level-ups, the whole story arc) **without a single API call and at zero cost.**
- **Free, fast, repeatable** → continuous UI/QA, screenshots, endurance runs and CI
  without budget or flakiness.
- Make it **switchable** in the real runtime (one flag/toggle) so the same build runs
  mock or real.
- Deterministic = reproducible bugs and snapshot-comparable outcomes.

### 5.2 Unit tests anchor behavior
Test the deterministic core (combat math, dice heuristics, scripted mock flows). A
unit test that drives the mock through a scripted fight or the whole 5-chapter arc
*proves* behavior more cheaply and reliably than manual clicking — and catches
regressions.

### 5.3 Endurance / soak runs for emergent bugs
Run long automated sessions (N turns) via the mock to find **emergent** problems that
don't surface in 3 turns: plateaus, repetition, desync drift, stalls. Many of our
best bugfixes came out of 25–50-turn mock runs.

### 5.4 Live verification stays mandatory
"Builds/transpiles/unit-tests green" covers no rendering or interaction behavior.
**Screenshot/play the real thing** for anything involving layout, stacking, gestures
or feel.

### 5.5 Budget-aware verification
Separate what you can verify for free (mock) from what requires the real (paid/AI)
backend (e.g. prompt tuning can't be mocked). Do the mockable part for free and
deterministically; deploy the expensive backend only where it must, and say so
explicitly.

---

## Part 6 — Build, deploy & ops

- **Set the cost ethos upfront.** Eldor runs at **€0/month**: the player brings their
  own API key (free tier), there is no central bill. Decide in the brief whether the
  next project follows the same ethos — it drives architecture (BYO-key vs. central
  backend), web-proxy necessity and monetization.
- **Supervised server + mock toggle.** Run the backend under a supervisor
  (launchd/systemd/PM2) with auto-restart, and make the mock toggle on/off on the
  same port with one flag, so you can QA for free without disturbing the stack.
- **Share quickly with a tunnel** (Cloudflare/ngrok) for tester feedback without a
  hosting setup.
- **Secrets via env/secure storage, never in git.** `.gitignore` keys, keystores,
  `.env`. A release keystore is an owner secret, not a repo artifact.
- **Verify builds on all targets** before you sign a feature off.

---

## Part 7 — Per-session working method (checklist)

1. Read the hub doc + the relevant domain doc; identify the *one* task.
2. Which files? Which known pitfalls apply to this kind of work?
3. Build the vertical slice → verify **behavior** (run/screenshot), not just the
   build.
4. Update PROGRESS + the relevant doc.
5. Commit with a clear, type-prefixed message (no secrets).
6. If context gets tight: split, don't push through.

---

## Part 8 — (OPTIONAL) AI/LLM-driven games

> **Skip this chapter for games without AI.** It applies only when an LLM is a player
> (narrator, director, NPC brain, generator).

### 8.1 When (not) to use an LLM
Use an LLM for **open, linguistic, unpredictable** content (story, dialogue, emergent
situations). Do **not** use it for anything that should be deterministic (rules,
math, economy, win conditions). Cardinal rule (= Part 1.1): **the LLM narrates, the
code decides.**

### 8.2 Tool/function-calling architecture (the agentic loop)
The LLM mutates state **only** via a fixed set of tools/functions the engine applies
deterministically; then the LLM narrates the returned numbers.
- An **agentic loop**: model → tool calls → engine dispatches → results back → model
  continues, until a normal turn-close.
- Mark tools that **return real info the model needs to narrate** (dice outcome,
  attack result) as "result tools" that **force a mandatory follow-up round** — so
  the model never narrates blind.
- **Mandatory consequences:** force in the prompt that the DM calls the relevant tool
  *before* telling the consequence (damage/loot/XP/combat) — story and state stay in
  sync.

### 8.3 Resilience (models fail erratically)
- **Retry empty completions** (a few times, short backoff).
- **Graceful degrade**: on persistent failure, force one call *without* tools so the
  player always gets narration.
- **Deterministic safety net**: if the model can't produce choices, inject
  context-aware fallback choices so there is always something to tap.
- **Don't break the illusion** on errors: catch raw API/JSON errors and reframe
  in-world or in a separate non-diegetic strip.

### 8.4 System-prompt structure (order = priority)
- **Authority first**: who may assert the world/facts (Part 1.3).
- **Status as source of truth**: mirror inventory, abilities, active goals and arc
  position into the prompt; instruct the model to use them *verbatim* and not invent
  or recreate anything.
- **Mandatory consequences** + the tool names.
- **Ladders/balance** (e.g. a DC table) — framed positively (Part 1.7).
- Preserve existing prompt sections: each is usually a fix for concrete real-world
  misbehavior. Don't remove without reason.

### 8.5 Prompt-engineering lessons (hard-won)
- **Anti-anchor** (Part 1.7): don't repeatedly name the value to avoid; frame
  positively. "Never use 12" → you get 12.
- **Localize injected data** (Part 1.8): the prompt is a *receiver* — feed it
  names/text in the player's language, not the canonical storage form.
- **History windowing vs. derived counters.** Token budget often forces a truncated
  history window to the model. Beware: any counter you derive *from that window*
  plateaus/oscillates. Feed derived counters from the *full* state, not the window.
- **Nudges steer emergent behavior** (auto-encounter after a dry streak, quest-nudge,
  repetition pivot) — but they have side effects: a hidden `[META]` nudge that counts
  as "the last input" can hijack downstream logic. Keep nudges recognizable and let
  consumers distinguish the *real* player input from injections.
- **Cheaper model = anchors faster.** A smaller/cheaper model needs tighter, more
  positive, shorter steering; reserve expensive models for where it matters.

### 8.6 Mock provider & cost
- The **mock provider** (Part 5.1) is, for AI games, *the* way to test the full
  engine/UI for free and deterministically — build it early.
- **Cost/privacy**: BYO-key (free tier) keeps it at €0 and the key with the player;
  web requires a proxy (Part 4.2). Don't send player data to endpoints the player
  didn't explicitly designate.

---

## Part 9 — Reference stack (Eldor) as a blueprint

A concrete example of the principles above; use as a blueprint, not a mandate.

- **Shared core = one Swift package (`EldorCore`)** with four modules:
  - `…Models` — pure value types (Character/Hero, Combat, Quest, Talent, StoryArc,
    Equipment, WorldState, Language, enums). No UI, no I/O.
  - `…Engine` — deterministic logic (CombatResolution, CharacterFactory,
    SystemPrompt builder, ToolSpecs, Heuristics).
  - `…Providers` — an `LLMProvider` protocol + implementations: `GeminiProvider`,
    `ClaudeProvider`, and the **`MockProvider`** (network-free).
  - `…Chat` — `ChatEngine`: the agentic tool loop, provider-agnostic.
- **iOS/macOS** — native SwiftUI shell; its own native chat path; `@Observable` +
  `@MainActor`, MVVM, no third-party packages, secrets in the Keychain.
- **Android** — **Skip (skip.tools)** transpiles the same Swift/SwiftUI → Kotlin/
  Compose; shares `EldorCore`. (See the Skip pitfall catalog, 47 entries, in the
  android docs.)
- **Web** — a **Vapor server** (Linux) hosts `EldorCore` + serves a **React/
  TypeScript frontend** (Zustand store, i18n, asset-free CSS juice: Atmosphere layer,
  parchment panels, drop-caps, floating numbers, crit-burst). The server holds/
  forwards the key (the web proxy).
- **One spec, four shells** — prompt, tool schemas, combat rules, models and art
  recipes live in/next to the core and are not re-invented per platform.
- **Ops** — launchd LaunchAgent with a mock toggle on port 8080; a Cloudflare tunnel
  for testers; €0/month (Gemini free tier, player BYO-key).
- **Docs pattern** — `CLAUDE.md` (hub) + `docs/*` (domain) + a living `PROGRESS.md`;
  an `aidm-rpg-game-feel` skill holding the juice recipes.

### Second reference stack — GRID_BREAKER (native single-platform arcade)
The counterpoint to Eldor's four-shell cross-platform build: a **deliberately
iOS-only** native reflex game. Proof that **not** going cross-platform is a valid,
simplifying choice when the brief doesn't need it (Part 4.1 is a *choice*, not a duty).

- **Shared core** = a Swift `Core/` (Models + Engine): `GridEngine` (deterministic
  struct), `SeededRNG` (SplitMix64), `GameConfig` factories, a `GameEvent` stream and
  `SessionSnapshot`. Single source of truth; the view only renders snapshots + events
  (Part 1.1 holds even with no server and no AI).
- **Determinism earns features for free**: a seeded engine → a **Daily Challenge**
  where everyone races the same seed, and **headless Swift sims** for balance + fuzz
  (Appendix E) — no device, no cost.
- **Presentation** = SwiftUI (`@Observable @MainActor` VM, Canvas/TimelineView);
  **all SFX synthesized in code** (AVAudioEngine PCM, no audio assets); **all art
  generated by CoreGraphics scripts** (icon, badges, marketing — no designer; Appendix D).
- **Meta/persistence** = Game Center (report-only) + a local `GameStore` (UserDefaults,
  tolerant decode) as the offline source of truth.
- **Shipped** to the App Store, Game Center, €0 hobby scale, full EU business/tax/DSA
  compliance (Appendices A–B); no backend anywhere.

---

## Part 10 — The New-Game Brief  *(FILL THIS IN)*

> This is the only part that changes per project. Fill it in as concretely as
> possible; the agent uses Parts 0–9 as rules and this as the assignment. Leave a
> field blank → the agent asks a targeted question before building.

### 10.1 Pitch & fantasy
- **Working title:** …
- **One-liner (the fantasy the player lives):** …
- **Why this, why now / inspirations & references:** …

### 10.2 Genre & core loop
- **Genre / subgenre:** …
- **Core loop (the 30-second cycle the player repeats):** …
- **Session length & pacing (quick bursts vs. long sessions):** …
- **Win/lose/progression conditions:** …
- **Audience & age:** …

### 10.3 Mechanics & systems
- **Central systems (combat, puzzles, economy, progression, crafting…):** …
- **Source of truth / who decides outcomes (Part 1.1):** …
- **Difficulty & balance approach (Part 1.7):** …
- **What is deterministic vs. procedural/generated:** …

### 10.4 AI?  *(if no → Part 8 does not apply)*
- **Does the game use an LLM/AI?** Yes / No
- **If yes: what role** (narrator / director / NPC brain / generator) **and which
  parts stay strictly deterministic?** …
- **Model/provider preference + cost ethos** (BYO-key/€0 vs. central backend): …

### 10.5 Platforms & stack
- **Target platforms** (iOS / Android / web / desktop / console) **+ priority:** …
- **Web in scope?** (if yes → plan a backend proxy, Part 4.2) …
- **Stack choice** (shared-Swift+Skip / Flutter / Compose-MP / web-first-TS / other;
  see Part 4.1) **or "agent advises":** …

### 10.6 Look & feel
- **Art direction** (style, color, references): …
- **Audio direction** (music mood, SFX character): …
- **Game-feel priorities** (which of the 5 pillars weigh most, Part 2.1): …
- **UI tone** (diegetic/parchment, modern-minimal, retro…): …

### 10.7 Scope, cost & risk
- **Scope ambition** (prototype / vertical slice / full game): …
- **Time/budget per iteration & cost ceiling:** …
- **Monetization / distribution** (or: hobby, €0): …
- **Biggest risks / open questions:** …

### 10.8 Definition of Done for the first milestone
- **The first vertical slice is "done" when** (concrete, visible, playable): …

---

### Kickoff checklist for the agent (once Part 10 is filled in)
1. Confirm the stack choice and, if web is in scope, plan the backend proxy.
2. Sketch the layering (Part 3.1): what goes in the shared core vs. the shell.
3. Build **first** the **deterministic core + a mock/seam** (Part 5.1) so everything
   after is free and deterministic to test.
4. Deliver a **first vertical slice** that plays the core loop once end-to-end, and
   **verify behavior live** (screenshot/play session).
5. Set up the docs pattern (hub doc + living PROGRESS) and commit in logical slices.
6. Ask targeted questions for every blank/ambiguous brief field before building.

---

# Appendices — shipping a native game (learned from GRID_BREAKER)

> Parts 0–10 get a game *built*. These appendices cover everything *after*: getting it
> onto a store, staying legal, charging money ethically, making the art/marketing, and
> QA-ing a real-time game. **Optional** — skip for web-only or pre-release work. None
> of it is legal/tax advice; verify against current Apple/EU rules.

## Appendix A — Shipping a native app to the App Store
- **Two human-only blockers gate everything — start them first.** (1) **Apple Developer
  Program** enrollment (€99/yr); (2) **Agreements/Tax/Banking** ("Business") setup. Both
  burn real calendar time (verification/processing). Kick them off *before* the build is
  finished; everything else (QA, screenshots, copy, pages) preps in parallel.
- **Split every release task by owner.** Tag 👤 (maintainer: account/hardware/legal —
  can't be automated) vs 🤖 (agent: code, docs, assets, pre-flight). The agent does
  ~everything except what needs the Apple account, a physical device, or a signature.
- **Hosted legal pages are required before submit**: a **Privacy Policy URL** + **Support
  URL**, live on any static host. Reusable pattern: a `<username>.github.io` **user-site
  repo, one subfolder per app** (future apps = new subfolder, one Pages site). Use a
  **dedicated support email**, never your personal one; whatever's on these pages is public.
- **Pre-answer export compliance in the build**: `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption
  = NO` (when true) → the submit flow never prompts.
- **Asset specs that bite**: screenshots **6.9" = 1320×2868** (the one required size; Apple
  scales down); App **Preview video must match a device spec** (e.g. **886×1920, 30 fps**,
  H.264+AAC) — a raw screen-grab (wrong fps/size/no audio track) is rejected; app icon
  **1024×1024 opaque** (no alpha).
- **The uploaded build must finish processing (5–60 min) before you can attach it** to the
  version. Submitting an archive ≠ instantly attachable.
- **Most version fields lock once "Waiting for Review / In Review."** Non-urgent edits (App
  Review contact, an added localization) wait for the next version — don't pull a build
  from review for trivia.
- **Game Center = report-only meta** (Part 1.1): the engine stays authority, the bridge
  only *observes* the verified event stream and forwards; declining auth is a no-op. IDs in
  code must match App Store Connect **exactly**; achievement art is **1024×1024 that GC
  crops to a circle** (design a ring, not a card — verify with a circle-cropped contact
  sheet). The entitlement rides the App ID, and ASC needs Game Center **enabled on the
  version** (a separate checkbox) or submission is blocked.
- **External waits → scheduled reminders, not polling**: the review verdict, "swap the
  placeholder App Store URL once live," tax/legal follow-ups — set a dated reminder for
  things you can't act on yet and the tooling can't watch.
- **Write a click-by-click `appstoreconnect-walkthrough.md`** with every paste-ready value;
  it turns a multi-hour first submission into a guided checklist and is reusable next time.

## Appendix B — Business, tax & legal compliance (solo EU dev)
- **Free app needs only the Free Apps Agreement; *selling* needs the full stack** — Paid
  Apps Agreement + bank account + tax forms, all Active. Slow to verify → do it early.
- **U.S. tax forms for a non-US dev**: the **W-8BEN** certifies foreign status and **claims
  the treaty** — for the Netherlands that's **Article 12 (royalties), 0% rate, "income from
  sale of applications," foreign TIN = national tax number (BSN)** → **0% US withholding
  instead of 30%.** Apple also wants a **Certificate of Foreign Status** (type:
  individual/sole proprietor; "Title" for a one-person setup = e.g. *Owner*). Both are
  **irreversible on Submit** — and **US forms read dates as MM-DD-YYYY**, so check the format.
- **App Store Small Business Program** → **15%** commission (vs 30%) under $1M/yr.
  **Not retroactive — enroll before the first sale.**
- **DAC7** (EU platform-income reporting): the "personal services" question is **No** for a
  game (selling software ≠ a person performing a task for a user).
- **EU DSA trader status gates EU *availability* (even for a free app):**
  - You **must declare** trader or non-trader, or the app is withheld from the **entire EU
    store** — declaring is what keeps you in; leaving it blank is what pulls you.
  - **Non-trader** is the honest, correct answer for a **free, non-commercial hobby app**
    (no ads, no IAP), needs **no public contact info**, and still distributes in the EU.
  - **You cannot sell as a non-trader** → before enabling any IAP, **switch to trader**,
    which publishes **address + phone + email** on the product page. Use a **virtual-office
    / mail-service address**, not your home; **avoid a PO box** (DSA wants a geographical
    address).
- **Public-contact privacy**: DSA trader info and support pages are public forever — choose
  the address/email/phone deliberately.

## Appendix C — Ethical monetization without a backend
- **Model: free game + optional supporter IAPs.** No ads of any kind; paid-up-front
  rejected (kills casual discovery).
- **Hard rule: real money never touches the gameplay economy.** Never sell currency,
  upgrades, continues, difficulty, or score potential. Paid items are **cosmetic /
  render-layer only** — they *read* engine state, never write it (the determinism sim is
  the regression test). No loot boxes, FOMO timers, or post-game-over upsells.
- **Tip jar = StoreKit 2 consumables, zero backend**: `Product.purchase()` → verify →
  grant → **always `finish()`** (or it re-delivers forever). Run a long-lived
  **`Transaction.updates` listener** (Ask-to-Buy/retries), gate on **`canMakePayments`**,
  reframe `.pending`/offline/errors **in-world** (never raw errors). **Consumables aren't
  restorable → no Restore button** (that's only for non-consumable cosmetics).
- **Test for free with a `.storekit` config file**; **sandbox-test the real purchase on a
  device** before release (the one step neither a config file nor an agent can do).
- **Phase it**: ship free first; add the tip jar only once people actually play. Tip
  conversion is a fraction of a percent of actives — keep expectations honest.

## Appendix D — Generating app & marketing assets in code
- **A solo dev with no designer can produce the whole on-brand asset set programmatically**
  and regenerate it on a whim. **All raster art via CoreGraphics + CoreText + ImageIO**,
  committed as small parameterized scripts: app **icon** (opaque, `noneSkipLast`), **Game
  Center badges**, **OG/share card** (1200×630), **Instagram cards** (1080×1080 +
  1080×1920). One generator with flags (`soon|now`, optional screenshot) beats hand-editing.
- **Know each surface's crop/spec and verify it** (GC = circle → ring; OG = 1200×630) by
  *rendering* a cropped contact sheet, not assuming.
- **Video without ffmpeg**: AVFoundation — `AVAssetExportSession` to trim a clip,
  `AVAssetImageGenerator` + ImageIO to build an **animated GIF**; capture the App Preview
  itself via `simctl io recordVideo` (mind the fps/size spec).
- **All audio synthesized in code** (AVAudioEngine PCM) — no licensed SFX, no licensing
  risk, tiny bundle.
- **Reusable marketing kit**: a neon **landing page** (with OG/Twitter meta) on the
  user-site repo, plain + captioned screenshot sets, social cards in **teaser** ("coming
  soon" — name + a *blurred* gameplay glimpse for partial secrecy) and **launch** ("out
  now" — clearly a free iPhone game) variants, **per-platform captions** (IG feed/story,
  LinkedIn, X, Reddit, PH/HN), and a tiered **promo-channels** plan. **Tailor copy to the
  real audience** (wide/personal family-and-friends → drop the jargon). **Localize the
  listing** to the core market's language.

## Appendix E — QA for a deterministic real-time game
> The mock-provider lesson (Part 5) generalizes: a deterministic core lets you test almost
> everything headless — even an action game you can't "play" through tooling.
- **Headless sims over the shared core** (`swiftc -O` on `Core/*.swift` + a `main.swift`)
  tune balance (spawn/lifespan curves, difficulty ramp) and run **invariant fuzz**
  (thousands of seeded runs asserting no OOB / duplicate-cell / illegal-state) — free,
  fast, no device. The action-game analogue of Eldor's mock-provider soak runs.
- **A seeded, deterministic engine is the enabler**: same seed → identical session →
  comparable snapshots → a shareable daily-seed board + reproducible bug reports.
- **Reflex gameplay can't be driven at tool/agent latency** (the live clock drains during
  each round-trip). So **sims validate balance**, and **temporary in-code autoplay /
  state-override hooks** force the app into exact states for **screenshots and the preview
  video** — then are **reverted (and grepped for residue) before any commit**.
- **A live device pass stays mandatory** for what sims can't judge: **audio mix, haptics
  feel, VoiceOver, Reduce Motion**, overall game feel. Build-green ≠ feels good.
