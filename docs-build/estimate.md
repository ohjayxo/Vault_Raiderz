# Vault Raiderz Slice — Engineering Estimate (Build Step 0A)

Written 2026-09-19. Owner: Claude Code, for Josh. Not a design file; nothing
in `docs/` was changed.

**What I read:** `10-roadmap.md` (Vertical Slice, Build Order, Known Risks),
`13-build-guide.md` (all of Part E, plus Parts C/D that Part E leans on),
and in `02-core-loop.md` the FTUE, sharding, combat, Bank/Exposed, Raiding,
Chase, Defenses, Base, and Automation sections; `06-economy.md` §
Exchange/Trade Safety; and the headings of `03`–`06`.
**What I did not read yet:** the full text of `03-progression.md` (Tech Path,
Crews, Research Bench, Level/Reputation), `05-items.md` (Grade, Gear score),
and `04-world-content.md` (Scav Waves). Steps 5, 6, 9, 10, 11 are sized
from checklists and headings, so treat those sizes as ±1 size class until
each step's plan phase reads its docs.

## How to read the sizes

A **session** = one loop of plan → build → test in Studio → fix → review →
commit. Roughly 2–4 hours of Josh's time, because Studio testing (especially
with Clients and Servers) is slow and mostly manual.

| Size | Sessions | Meaning |
|---|---|---|
| S | ~1 | One system, few remotes, little persistence |
| M | 2–3 | One system with UI, or two small ones |
| L | 4–6 | Multi-part system; touches data, UI and validation |
| XL | 7+ | Cross-server state or several interacting systems |

These are **guesses, not measurements**. Josh is new to Roblox, and
Studio-only bugs (replication, quotas, published-place requirements) are
the main source of surprise. Sizes assume the existing scaffold (Step S:
Rojo, `Config.luau`, `Remotes.luau`, vendored ProfileStore) is done, which
it is.

## Summary table

| # | Step | Size | Riskiest part |
|---|---|---|---|
| 1 | Data layer | **L** | Profile schema that must survive 13 more steps |
| 2 | Node collection + Grade | **M** | Server-side mining validation + the BroadcastQueue |
| 3 | Vault Core + Bank/Exposed | **S** | Exposed/Banked accounting bugs (dupe/negative) |
| 4 | Base building + budget | **L** | Touch-friendly placement UX + persisting placed pieces |
| 5 | Combat + pickaxe tree | **L** | Server-validated melee that feels okay on mobile latency |
| 6 | Defenses + Scav Waves + Captain | **L** | NPC wave AI + defense charges + wave ceiling |
| 7 | Raiding + Chase + escort | **XL** | Offline raid (presence/lock/message) and the Chase state machine |
| 8 | Charges, Riftsalt, band, shields | **L** | Band/gear-score/shield rules interacting (R6) |
| 9 | NPC sell, direct trade, Level/Rep | **L** | Trade atomicity + two-player UI |
| 10 | Workshop I, Tier 1 Tech, Bench, Blueprints | **L** | Tree data model + vertical mobile UI |
| 11 | Crews | **XL** | Crew Vault as a second session-locked store; tenure lockout |
| 12 | Offline production | **M** | Server-timestamp payout math on login |
| 13 | Analytics | **S** | Retrofitting events into 12 finished systems |
| 14 | FTUE polish | **L** | Hiding every system for the first 6 minutes |

**Rough total, midpoints (S=1, M=2.5, L=5, XL=8):** about 63 sessions. If the
three blow-up steps below each go 2–3x, the total is roughly **85–105
sessions** (steps 7 and 11 add 8–16 each, step 4 adds 5–10: 63 + 21–42 =
84–105, call it 85–105). At 3 sessions a week that's ~21 weeks nominal,
~28–35 weeks bad case. Step 0B (the phone test) is not counted; it needs a real cheap phone
and must happen **before step 4**.

---

## Step-by-step

### 1 — Server-authoritative data layer · **L** (use Opus)
- **Needs:** `DataService` (ProfileStore wrapper, profile template, schema
  version + migrations), `RateLimiter` shared helper, remote-validation
  wrapper around `Remotes.luau`, bitpacked flags (D80), plot-archive
  lifecycle field + archive/restore functions (D55), Studio-only debug
  print command, a thin `Analytics` stub (see cross-cutting notes).
- **Riskiest:** the profile template. Every later step (Banked/Exposed,
  plot, Tech Path, blueprints, crew membership, Level/Rep, shield
  timestamps, drone timers) hangs off it. A wrong shape means migrations
  in every later step.
- **2–3x if:** the template has to be reworked once step 4/7/10 reveal
  missing fields; session-lock handling on leave/rejoin in Studio
  misbehaves; Studio API access/published-place setup (Part B8) isn't
  right; bitpacking is over-engineered up front. D55 archiving can't be
  tested against a real 1-year clock: build and unit-test the function
  with a debug clock, don't wait for real data.

### 2 — Node collection + Grade rolls · **M**
- **Needs:** `NodeService` (tagged nodes, respawn, rich-node landmarks),
  `GradeService` (server-only rolls; odds live only in Config),
  `BroadcastQueue` (D58) for the Vaultborn announcement (zone-level
  message), debug HUD, mining rate limit + anomaly log.
- **Riskiest:** the mining remote: distance/line-of-sight/cooldown checks
  that are strict enough to stop exploits but not so strict that lag makes
  honest mining fail on mobile.
- **2–3x if:** the BroadcastQueue is built more generally than step 2
  needs (it must eventually carry raid alerts and Chase pings, so
  the priority/drop rules matter, but only build per-server now);
  respawn timing spread across nodes; "odds never reach the client" leaks
  via a debug HUD or attributes.

### 3 — Vault Core + Bank/Exposed · **S**
- **Needs:** `VaultService` (capacity, bank/expose accounting, auto-bank for
  Prismatic/Vaultborn, separate Scrap cap), HUD meter. The Vault Core model
  is created here; *placement* comes in step 4.
- **Riskiest:** it is the invariant everything else trusts: banked +
  exposed must never go negative or duplicate.
- **2–3x if:** the meter needs more UI polish than a debug bar; special
  cases interact (Scrap cap + auto-bank + overflow order). Also the
  Step 3/4 seam: FTUE's "BUILD VAULT" button wants placement to exist.
  Keep Vault Core auto-placed on the plot for now.

### 4 — Base building + build budget · **L**
- **Needs:** `PlotService` (plot assignment, ownership), `BuildService`
  (placement validation, D57 budget from `Budget` attributes, persistence
  of placed pieces), client placement UI (touch-first), sharding **stub**
  ("one neighborhood per server") that still contains the D66 band metric
  code path (D56/D79).
- **Riskiest:** placement on a phone: drag/rotate/snap with touch is much
  harder to get right than click-to-place; server must re-validate every
  placement (overlap, bounds, budget, ownership).
- **2–3x if:** the step-0B phone test says base size or LOD rules must
  change (Known Risk #3); persisted-piece format churns; the band metric
  needs values (gear score) that don't exist until step 5, so a
  placeholder is needed.

### 5 — Combat + pickaxe + upgrade tree · **L**
- **Needs:** `CombatService` (3-hit combo, server hit validation,
  knockback), `PickaxeService` (3 branches × points, respec cost from
  resources), gadgets (Smoke Bomb, Sprint Serum, Shock Trap, Disruptor),
  gear score calc (D92, server-side only), simple hittable NPC dummy.
- **Riskiest:** combat feel vs server authority. The client's swing is a
  *request*; if the server validates too strictly, hits feel dead on
  mobile ping, too loosely and it's exploitable (R5).
- **2–3x if:** gadgets are more work than the checklist suggests (the docs
  list four, and Disruptor needs defenses from step 6, so stub it here);
  aim-assist/generous-hitbox tuning eats sessions; XL if Josh wants combat
  to feel good, not merely correct.

### 6 — Defenses + Scav Waves + Scav Captain · **L**
- **Needs:** `DefenseService` (slots, charges, refill costs; six defense
  types), `ScavService` (wave spawner, simple pathing AI, wave ceiling with
  queue per D59, mobs-never-destroy per D87), Captain + four-bucket loot
  table, Captain loot to defender (D107).
- **Riskiest:** NPC AI and pathfinding around player-built bases;
  Roblox's PathfindingService can do strange things with player-placed walls.
- **2–3x if:** waves + defenses + player-built layouts create unbeatable or
  trivial combinations; the server-wide wave cap needs cross-server
  coordination (if it must count across servers it's a MemoryStore problem;
  if per-server it's easy. Confirm scope in the plan).
- **Scope stub:** the PvE ladder row lists "Standard Cases" as Captain loot;
  Cases are out of the slice, so that bucket entry is stubbed.

### 7 — Raiding + lockpick + Chase + raid escort · **XL** (use Opus, run Prompt R twice)
- **Needs:** `PresenceService` (MemoryStore presence keys with TTL/refresh),
  `RaidLockService` (raid locks, backoff), `RaidService` (breach,
  lockpick minigame, grab, escape window, transit state, theft math,
  ~20% destroyed in transit), `ChaseService` (slow, gadgets off, server-wide
  mark + trail, knock-loose returns loot), escort body-block rules (D101),
  ProfileStore-message delivery of theft to victim, raid log + path map
  (D105), tier 1–7 interaction, BroadcastQueue priority for raid alerts.
- **Riskiest:** the offline raid. Two servers touching one player's
  profile; the guide's five-step pattern is the only allowed approach.
  Every "try to break it" scenario in the checklist is a real dupe risk:
  victim rejoins mid-raid, raider leaves mid-Chase, two raiders on
  one offline base.
- **2–3x if:** the design gaps below aren't resolved before starting
  (offline plot loading, target discovery); MemoryStore's tiny Studio
  quota hides real behavior so bugs appear only with real players;
  Chase edge cases (carrier dies, disconnects, teleports, leaves the
  zone) each need their own rule; testing needs 3+ Studio clients and
  repeated timing-sensitive runs.
- **Also build here:** a derelict-vault raid hook (guided/easy lockpick,
  guaranteed reward) so step 14 doesn't have to rip into the raid state
  machine.

### 8 — Breach Charges, Riftsalt, raid band, shields · **L** (use Opus)
- **Needs:** `RiftsaltService` (Reaches-only spawns), craft charges,
  `BandService` (highest of tier/lifetime peak/gear score, D66/D92),
  `ShieldService` (48h new-account, 30-min post-raid, Blackout exemptions,
  D67/D75), small Reaches area, precondition checks in `RaidService`.
- **Riskiest:** shields and band are *safety* rules (R6). Time math must
  use server clocks, survive logout, and not be reset by rejoining.
- **2–3x if:** the "small Reaches" world needs more building than
  expected (it's map work, not code, so it is easy to underestimate);
  band inputs (lifetime peak, gear score) weren't stored in step 1's
  schema; testing 48-hour timers needs a debug clock in every timer path.

### 9 — NPC selling, direct trade, Level/Reputation gate · **L**
- **Needs:** `SellService` (Credits, per-sale price decay, daily reset,
  D94), `TradeService` (two-player window, 5s confirm lock, history log,
  D98 value-threshold hold), `ReputationService` (XP tracks, Level,
  Level-10 gate), trade UI (both sides visible), Robux-pool separation is
  out (no Robux) so the trade window has one pool only.
- **Riskiest:** trade atomicity: both sides must swap or neither, with
  session-locked profiles on possibly different servers.
- **2–3x if:** trade is allowed across servers (I assume same-server only
  in the slice; confirm); UI for two players is more than a debug window;
  Reputation XP hooks into steps 2/7/9 that were built without it (adds
  edits to finished services).
- **Gap:** "below-market warning" needs a reference price and there's no
  Exchange in the slice. See open questions.

### 10 — Workshop I, Tier 1 Tech Path, Research Bench, Common Blueprints · **L**
- **Needs:** `WorkshopService` (placeable, tier I), `TechPathService`
  (node data, prerequisites, Scrap costs, permanent, respec at 50% [PH]),
  `ResearchService` (consume item + Scrap → learn blueprint, bound on
  learn), `BlueprintService` (Common only), vertical mobile tree UI (D60).
- **Riskiest:** the tree UI on a phone; the data model itself is easy.
- **2–3x if:** Tier 1 tree content is more than a list of nodes (effects
  must plug into steps 2/5 stats, so every node is an edit to another
  system); the "full tree visible" rule (D108) needs layout work.

### 11 — Crews · **XL**
- **Needs:** `CrewService` (invite/accept, no chat, D61), `CrewVaultService`
  (its own session-locked store; leader full access, member withdraw cap,
  D90; disband split, D91), shared T1 node grants with 24h tenure
  lockout (D25/D109) that **revoke** on leave, crew UI, debug clock.
- **Riskiest:** a second session-locked store with members on different
  servers depositing/withdrawing concurrently, plus grants that must
  revoke correctly. It's the same class of bug as offline raiding, with
  more moving parts.
- **2–3x if:** crew membership needs cross-server lookup for invites
  (Invite by player when they're on another server?); lockout interacts
  with Tech Path respec and permanence (D72); disband with offline members
  needs the message pattern again.

### 12 — Offline production (one Harvester Drone) · **M**
- **Needs:** `DroneService` (craftable, placeable, output rate in Config),
  "while you were away" payout on load (server timestamps, capped, slower
  than active play per R3), payout UI.
- **Riskiest:** clock math: must use server time and survive quick
  rejoin/duplicate-payout races.
- **2–3x if:** the Drone's recipe/rate/cap aren't in the docs (I haven't
  verified; if missing, add as `[PH] invented`); payout interacts with
  Bank/Exposed capacity (overflow to Exposed on login, where offline
  raids can steal it; behavior needs to be stated).

### 13 — Instrument analytics · **S** (only if the stub exists from step 1)
- **Needs:** `AnalyticsService` wrapper over Roblox `AnalyticsService`;
  FTUE funnel, session length, first-raid-loss events; verify in Creator
  Dashboard.
- **Riskiest:** retrofitting. Part D says "from day one" while the build
  order puts it at 13. If events weren't added as systems were built,
  this becomes an edit across ~10 services.
- **2–3x if:** dashboards lag by up to a day so verification is slow; event
  names change and history breaks.

### 14 — FTUE polish · **L**
- **Needs:** `FtueService` (server-tracked state, guided first-node spawn,
  no text before 2:30, free cosmetic grant, first-raid derelict vault),
  FTUE visibility gating across every UI built in steps 2–13, timing
  tuning, real-person playtests.
- **Riskiest:** rule 5: nothing from tech tree, market, crews etc. may be
  visible. If every earlier UI was built always-on, hiding it means edits
  to every screen.
- **2–3x if:** playtests turn up confusion (they will; that's the point);
  the 10-second/60-second targets need engine-level tricks (spawn timing,
  streaming); each tuning loop needs a fresh account and a fresh 48h shield.

---

## The three steps most likely to blow up

1. **Step 7, Raiding + Chase.** Offline raiding is the most exploit-sensitive
   system, it has the most unstated edge cases, and two design questions
   (below) sit right in front of it. Testing needs several clients and
   timing-dependent scenarios. If step 7 goes 2x it's +8 sessions on its
   own; Step 8 inherits every bug.
2. **Step 11, Crews.** It looks like "just another feature" but contains a
   second session-locked store, cross-server concurrent access, and a
   revocation rule. Underestimated because it sounds social, not
   architectural.
3. **Step 4, Base building.** Touch placement UX, persistence of arbitrary
   player layouts, and a budget that depends on the phone test in 0B. The
   risk isn't the code volume; it's that a bad 0B result forces a redesign
   of piece counts/LOD *after* this step is built.

**Near misses:** Step 1 (small blast radius if right, huge if the schema is
wrong; gets Opus for that reason) and Step 14 (bounded by playtest
iteration, but expands if earlier UIs weren't built hideable).

## What to cut first if the total is too big

Rule (D108): cut from the bottom of the build order only; never steps 1–8.
Strict bottom-up order and what each cut costs:

| Cut order | Step | What you lose | Consequence |
|---|---|---|---|
| 1st | **14 FTUE polish** | Tuned first 6 minutes | D1 retention (the number the slice exists to measure) will be dominated by a rough FTUE |
| 2nd | **13 Analytics** | Measurement | The slice can't answer its own success criteria |
| 3rd | **12 Offline production** | D1 pull-back hook | Removes the thing D1 is supposed to test |
| 4th | **11 Crews** | Two of the design's "biggest open bets" | Saves ~8 sessions; the highest-value cut on the list |
| 5th | **10 Workshop/Tech/Bench** | Progression identity | Leaves the game with no long-term goal |
| 6th | **9 Selling/trade/Level** | Economy layer | No Credits sink; the economy layer is gone |

**My honest read:** the strict bottom-up rule and the slice's *purpose*
disagree. 14 and 13 sit at the bottom but are small and are how the slice
gets judged; cutting them first saves ~6 sessions and makes the whole exercise
unmeasurable. **Step 11 (Crews) is the best cut per session saved.**
Before applying the rule mechanically, I'd take that to the design project
and ask whether D108's "cut from the bottom" means "highest step numbers"
or "least essential steps at the bottom half." If it means
the latter: cut **11 → 12 → 10**, keep 13 and 14 (small, essential).
I won't decide that myself. If Crews go, the crew-shared Tech Path nodes
(D25) and the Crew Vault go with them; steps 10 and 12 don't depend on crews.

**Cheap trims that need no scope change** (implementation choices, not
design): build each UI as a plain debug panel until step 14 rather than
polishing as you go; keep sharding stubbed as "one neighborhood per
server" (step 4 already allows it); stub Disruptor until step 6.

## Cross-cutting recommendations

1. **Analytics timing.** `13-build-guide.md § Analytics` says "from day
   one"; `10-roadmap.md § Build Order` puts it at step 13. Recommend a
   thin `Analytics.log(eventName, fields)` stub in step 1, called as each
   system lands. Step 13 then becomes wiring plus verification.
2. **FTUE hideability.** From step 2 on, every player-facing UI panel
   gets registered with a visibility flag (default hidden until unlocked).
   Step 14 then flips flags rather than editing screens (R4).
3. **Derelict vault hook in step 7** (see above).
4. **Debug clock.** One `Clock` module (server time, Studio-only offset)
   used by shields, tenure lockout, drone payout, price-decay reset, trade
   holds. Otherwise steps 8, 9, 11, 12 each invent one.
5. **Opus per the guide:** steps 1, 7, 8; I'd add 11 for the crew-vault
   store.

## Design questions to settle before the step that needs them

Per CLAUDE.md I'm not inventing behavior. Josh approved my picks on the
first two (2026-09-19). They are **working decisions for the build only**:
`docs/` still doesn't say this, so they need to go back to the design
project and into `02`/`06` (see "To sync back" below). The last two are
deferred to their steps' plan phase.

**Before step 7 — offline raids: where does the raider physically go?**
**DECIDED (Josh): (a) snapshot.**
`02-core-loop.md § Raiding` and `13 § Part D` describe the *math* of an
offline raid (victim's last saved Exposed, lock, message) but not how the
victim's base *geometry* exists on the raider's server, or how the raider
finds an offline target. `D56`/`D79` say shards host "a set of plots"
without saying whether offline players' plots stay resident.
- (a) Raider's server loads a read-only snapshot of the victim's plot into
  a temporary slot. *(my pick: matches "read-only view" in Part D)*
- (b) Offline players' plots stay resident in their band's shard as static
  "ghost" plots.
- (c) Offline raids skip the base walk (auto-resolve). Conflicts with the
  lockpick and path-map (D105) design.

**Before step 9 — the "below-market warning" (Trade Safety) has no market
in the slice.** No Exchange means no market average.
**DECIDED (Josh): (a) NPC base price.**
- (a) Use NPC base price per item as the reference. *(my pick)*
- (b) Skip the warning in the slice.
- (c) Static reference price per item in Config.

**Before step 12 — drone economics** (recipe, rate, offline cap, and whether
offline payout can land in Exposed and be raided) — I haven't verified
whether `02 § Automation` or `05` state them. Missing numbers will go into
Config as `[PH] invented`; missing *behavior* (overflow rule) I'll ask.

**Before step 6 — is the Scav Wave ceiling (D59) per-server or global?**
Per-server is easy; global needs MemoryStore. I'll confirm from
`04-world-content.md § Scav Waves` in that step's plan.

## To sync back to the design project

1. **Offline raid base loading (step 7):** the raider's server loads a
   read-only snapshot of the victim's plot into a temporary slot; the
   theft is still applied via the Part D message pattern. Target discovery
   for offline players still needs a rule (band-filtered list of offline
   plots?). I'll raise that in the step 7 plan, not assume it.
2. **Below-market warning (step 9):** in the slice the reference price is
   the NPC base price per item (D94's undecayed price). Needs a line in
   `06-economy.md § Trade Safety`.

## Step 0B reminder (not part of this estimate)

The mobile performance spike needs a real cheap phone, stand-in meshes with
realistic triangle counts, and must be done and recorded **before step 4**.
Its result can change step 4's size (L → XL) if base size or LOD rules move.

## Scope change (2026-09-20)

**D112 adds armor to the slice**, by Josh's call as owner. It adds roughly **+2
sessions**: the data shape in step 1 (done), the crafting, equip and
knockback/damage-reduction effect in step 5 (5 stays L), and spare-armor theft
in step 7 (7 stays XL). The new total is ~65 sessions nominal.
