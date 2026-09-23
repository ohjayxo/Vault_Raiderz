# 10 — Roadmap, Scope & Risks

---

# ⚠ SCOPE WARNING — READ FIRST

**Vault Raiderz as fully designed is a large game.** Three rarity
systems, a global market, persistent plots, seasons, a ranked ladder, a
tech tree, upgrade trees, world events, crews, a PvE boss ladder,
farming, cases, blueprints, and raiding.

**This is not a first project, and it should not be built all at once.**

The realistic path is a **vertical slice** — a small, complete,
playtestable game — with everything else layered in only after retention
is proven. Shipping the full design at launch also leaves nothing to
announce in month three, which is how games go stale.

A future session reading these documents should **not** design Season 4
features while v1 does not exist.

---

# VERTICAL SLICE `[LOCKED — D53 direction, D107 final scope]`

**Scope call: "richer," not minimal.** The original minimal slice below
was superseded once core progression and social systems were judged
cheap relative to their payoff — mostly because they reuse
infrastructure (Bank/Exposed, server-authoritative validation, the
raiding loop) the minimal slice needed anyway. See `07-decisions.md §
D53`.

## In scope

| System | Why it's essential |
|---|---|
| **FTUE** exactly as specced | Highest-risk system; must be right |
| **Collection loop** — tap nodes, get resources | The core verb |
| **Grade system** | The variable-reward engine; cheap to build |
| **Bank vs Exposed** (including the small separate Scrap cap) | The central balance mechanic |
| **Vault Core + basic base building** | Visible progress; the thing you protect |
| **Raiding + the Chase** | The hook the game is sold on |
| **Breach Charges + Riftsalt** (tradeable via direct player trade, not the full global Exchange) | Makes raiding self-balancing and protects new players |
| **Three resources** (Stone, Ore, Riftsalt) | Enough for decisions, not overwhelming; Riftsalt is required for raiding, which is already in the minimal slice |
| **One zone** (Homestead) + a small Reaches | Minimum viable world |
| **Scavs + Scav Captain** | Teaches combat and defense safely |
| **NPC flat-price selling** | Economy without full market infrastructure |
| **Workshop I** (single tier) | Cheap relative to payoff; unlocks real progression identity early |
| **Tier 1 Tech Path** (one branch set) — **permanent, never resets (D72)** | Lets playtesting validate the "your tech path is your class" bet early |
| **Research Bench** | Reuses the Bank/Exposed and looting systems already in scope |
| **Common-tier Blueprints only** | Enough to test the knowledge-scarcity loop without the full three-tier system |
| **Crews (2–4)** — shared Crew Vault, crew-shared Tier 1 Tech Path nodes with the join/leave tenure lockout | Validates two of the design's biggest open bets (crew formation, shared progression) as early as possible |
| **One craftable Harvester Drone** (D110) — no Robux version | Offline production is mandatory (`02-core-loop.md § Automation`) and is the D1 pull-back hook the slice exists to measure |
| **Raid escort** (D101) | Gives friends a shared activity before crew raids unlock (D4) |
| **Minimal Level + Reputation** (D81, D82) | Required: D82 gates direct trading at Level 10, and direct trading is in the slice |
| **Armor** (D112) — craftable pieces, one chest slot | Added by the owner in the build phase: a defense gear goal, and a loss stake (spare pieces stealable) the pickaxe doesn't have |
| **Server-authoritative architecture (R5)** | Cannot be retrofitted |
| **New player protections (R6)** — tier bands with gear score (D66, D92), shields incl. Blackout exemptions (D67, D75) | Cannot be retrofitted |

## Explicitly still out of the slice

Workshop II/III + Fragments · Tier 2/3 Tech Path · Advanced/Prototype
Blueprints + Blueprint Mastery · Voltstone (deferred until the slice
proves out the three-resource base) · the full global cross-server
Exchange with price history · Cases/Keys · Condition + Pattern rarity
system · Seasons/ranked ladder · Marks · Rebirth (S2+, D86) · pets
(S2, D100) · the PvE boss ladder beyond Scav Captain
(Reach Warden, Glutton, Rift Bosses, World Boss) · Riftfall and other
dynamic events · elite-tier (8–10) raid destruction, since no vault tier
in the slice reaches that band · Farming/Greenhouse (still launch-scope
per D18, not slice) · Automation beyond one craftable Harvester Drone,
including the Robux drone gamepass (D110)

**Why the line sits here:** everything included reuses systems the
minimal slice already required. Everything excluded either needs
infrastructure the slice deliberately avoids (the global market's
cross-server MemoryStore architecture) or depth that only matters once
there's a real population to test against (Seasons, the full boss
ladder, Patterns). **This line is final (D107).** The engineering
estimate is now the first build-phase task (`§ Build Order`, step 0),
not a design gate — if it comes back over budget, cut from the bottom of
the build order rather than reopening the design.

## Success criteria before expanding `[LOCKED — D108; targets PH]`

| Metric | Target |
|---|---|
| D1 retention | ≥ 20% (decent), aiming 30% |
| Average session | ≥ 15 min in the slice |
| New-player churn after first raid loss | Monitor closely — this is the make-or-break number |
| Crash/exploit incidents | Near zero on economy actions |

**Do not expand scope while D1 is below 15%.** Marketing a game with low
retention wastes money.

---

# LAUNCH SCOPE (v1.0) `[PROPOSED]`

Everything in the slice, plus:

- All four resources (Stone, Ore, Voltstone, Riftsalt)
- All four zones
- Workshops I–III + Fragments
- Tech Path (all three tiers)
- Research Bench + blueprints
- Full PvE ladder (Scav Captain → Warden → Glutton → Rift bosses)
- Cases + Keys (Option A)
- Condition + Pattern, with **2–3 Unstable Finishes** (Q16)
- Global market with price history
- Crews (2–4)
- Ranked ladder + Season 1
- **Farming / Greenhouse**
- Riftfall, Ion Storm, Merchant Caravan, Blackout
- World Caches + Static Secrets
- Full cosmetic line + Trophy Hall

---

# SEASON PLAN `[PROPOSED]`

Seasons run **6 weeks** [PH], with a **Tier 3 reset at mid-season** (week
3) and a Tier 2 + Tier 3 reset at the boundary (D72; mechanics live in
`03-progression.md § Staggered tier reset`). Every season ships, at minimum: a themed
cosmetic line, **one new Unstable Finish**, a rotating world event, an
exclusive rank reward, and a swapped Rift boss with a fresh Prototype
table.

| Season | Headline addition |
|---|---|
| **S1** | Launch |
| **S2** | **Teas / Brewery** — the deferred consumable layer (`04-world-content.md`) |
| **S3** | Crew territory / endgame content (addresses the endgame gap) |
| **S4+** | TBD — driven by data, not by this document |

**Why teas are the S2 headline:** they're the content drop for exactly
the moment veterans run out of things to do, and their
newcomer-supplies-veteran economics matter most once a real economy
exists to sell into.

---

# KNOWN RISKS & GAPS

Ordered by severity.

## 1. Exploit resistance — lowest rubric score (6/10)
An economy + theft + randomized high-value drops is the most attractive
exploit target possible. Steal a Brainrot's documented cheater problem is
the precedent.

**Mitigation:** R5 from day one. Server-authoritative everything.
Rate-limit mining. Anomaly detection on impossible income rates.
**This cannot be retrofitted.**

## 2. Complexity creep vs. comprehension
Rubric criterion #1 is weighted heaviest and has been under pressure
since v4. Protected only by R4.

**Mitigation:** every new system must be checked against "is this
invisible in the first 10 minutes?" If not, it doesn't ship.

## 3. Mobile performance budget — target now known, not yet tested `[UPDATED]`
Persistent plots + visible bases + Grade particles + procedural seeds is
a lot of draw calls on a phone. **The target is no longer unknown:**
Roblox's own guidance is ~1,000 draw calls and ~1,000,000 triangles
scene-wide for a baseline device (`09-research.md § Rendering & Mobile
Performance Budget`), with individual meshes capped around 20,000–21,000
triangles and UGC accessories around 4,000.

**The risk:** the core loop depends on visually scouting neighboring
bases from a distance, which means the budget above has to cover your
own base, every visible neighbor, active Grade effects, and Pattern
cosmetics simultaneously. LOD and occlusion culling on neighboring bases
are load-bearing, not optional polish.

**Action:** prototype a dense multi-base scene early and test on
genuinely low-end hardware, not just Studio on desktop.

## 4. Social safety and chat age-gating — real platform constraint, not just "needs a plan" `[UPDATED]`
Young audience, trading, crews. Trade scams and social engineering will
happen — that part of the risk is unchanged. But there's now a concrete
platform mechanic to design around: Roblox's 2026 chat age-check
requirement means **experience chat is off by default for under-9
users** and adult-minor communication is restricted by default
(`09-research.md § Platform Policy — Chat & Social Age-Gating`).

**The risk:** crew coordination, Workshop III rental's trust-based
social interaction, and market negotiation all currently assume players
can talk to each other. For a meaningful share of the target audience,
they may not be able to.

**Mitigation:** design every social mechanic (crew invites, trade offers,
Workshop access grants) to fully function through UI/game systems alone
— icon-based requests, preset offers — never assuming chat carries any
of it.

## 5. Data architecture — DataStore's 2026 restructure changes the scaling assumption `[NEW]`
DataStore moved from a per-server budget to a single shared pool per
experience, with a hard total storage cap (baseline 500 MB + 1 MB per
lifetime player, effective July 2026) — see `09-research.md § Data
Architecture`.

**The risk:** persistent plots for every player, forever (`07-decisions.md
§ D6`), plus a global market, is exactly the unbounded-growth pattern
this cap is designed to catch. A successful game with a large lifetime
player count will hit real ceilings without deliberate data hygiene.

**Action:** build the data lifecycle policy into the initial
server-authoritative data layer (`§ Build Order`, step 1): plot archiving
(D55), stale-listing expiry, and bitpacking for small flags (D80). Full
payload compression for large fields stays deferred until real usage
data exists (D54).

## 6. Pattern system feasibility — sharper than previously known `[UPDATED]` (v1.0 risk, not slice)
Roblox has no custom shaders, confirmed still true in 2026. The sharper
finding: `SurfaceAppearance` properties generally can't be modified by
script at runtime at all, except for live color tinting
(`09-research.md § No Custom Shaders`).

**Consequence:** the "reliable" Pattern fallback needs revision — hue/tint
variation is confirmed runtime-doable, but UV-offset and overlay-layer
swapping likely aren't achievable live. The practical path is discrete
pre-baked texture variants selected by seed bucket, with tint layered on
top.

**Action:** prototype this specific approach before promising the
ambitious version in any pitch or marketing material.

## 7. Emotional harshness for young players
Documented in the market leader. Mitigated by R1, R2, R6 and auto-bank
protection — but this remains a game where a child can lose things.

**Candidate softener:** small percentage refund on the first raid of the
day.

## 8. Market manipulation — unsolved
Wash trading, price fixing, alt-farming. Partial defenses proposed in
`06-economy.md`, none proven.

## 9. Endgame — partially addressed
Seasons help. Crew territory (S3) is the candidate answer. Still not
fully resolved.

---

# BUILD ORDER `[LOCKED — D108]`

Sequencing for the slice. Every step covers a system in
`§ Vertical Slice`; if the step-0 estimate comes back over budget, cut
from the bottom, never from steps 1–8.

0. **Engineering estimate + mobile performance spike** — size the slice
   in Claude Code, and prototype a dense multi-base scene on genuinely
   low-end hardware (`§ Known Risks #3`) before committing to base
   visuals
1. **Server-authoritative data layer** — player profile, resources,
   DataStore persistence, plot archiving (D55), bitpacked flags (D80).
   Everything else sits on this.
2. **Node collection + Grade rolls** — the core verb, server-validated
3. **Vault Core + Bank/Exposed** — the balance mechanic
4. **Base building basics + build budget (D57)** — visible progress
5. **Combat + pickaxe + upgrade tree** — one item, two uses
6. **Defenses + Scav Waves + Scav Captain** — PvE before PvP; teaches defense
7. **Raiding + lockpick + the Chase + raid escort (D101)** — the hook
8. **Breach Charges + Riftsalt + raid band (gear score, D92) + shields** —
   raid cost and new-player protection (R6)
9. **NPC selling (with price decay, D94) + direct trade + Level/Reputation
   gate (D82)** — the economy's first layer
10. **Workshop I + Tier 1 Tech Path + Research Bench + Common Blueprints**
11. **Crews** — invites (D61), Crew Vault (D90, D91), shared T1 nodes
    with tenure lockout (D25, D109)
12. **Offline production** — the pull-back hook
13. **Instrument analytics** — D1/D7, session length, churn-after-raid
14. **FTUE polish pass** — build it last, tune it hardest

Tooling: **Rojo** to sync code files into Roblox Studio; scripting in
Luau; 3D assets built externally (Blender for characters, SketchUp
viable for base/architectural geometry).

---

# VERSION HISTORY

| Version | Date | Changes |
|---|---|---|
| v1 | 2026-09 | Initial concept — Vaultbreakers named, core loop, base, monetization outline |
| v2 | 2026-09 | Combat, world layout, Bank/Exposed, theft math, defenses, events, PvE |
| v3 | 2026-09 | Research-informed: offline progression, Grade system, micro-FOMO, sharpened Chase. Rubric introduced (244/300) |
| v4 | 2026-09 | Locked Q1–Q13. Added Condition+Seed, World Caches, pickaxe tree, ranked ladder, seasons, raid cost. Rescored 261/300 |
| v4.1 | 2026-09 | Item taxonomy, Cases/Keys Option A, blueprints, Blueprint Mastery, PvE boss ladder |
| v4.2 | 2026-09-19 | Workshops, Tech Path (replaces classes), Research Bench, four-resource model, farming at launch, teas deferred to S2. |
| v5 | 2026-09-19 | Full questionnaire pass — Q14–Q58 answered (35 new decisions, D19–D53). Elite-tier raid destruction added (D23), gear/Fragments/Riftsalt made tradeable, crew systems fully specified (vault, tech-sharing with anti-exploit lockout, loot split), vertical slice scope expanded to "richer" (D53). Two questions explicitly left open (Q33, Q34); one contradiction between Q14 and Q44 reconciled and flagged (D48). |
| v5.1 | 2026-09-19 | Platform limitations audit: DataStore's 2026 per-experience restructure and storage cap, concrete mobile rendering budget (~1,000 draw calls / ~1M triangles), confirmed no custom shaders with a sharper SurfaceAppearance runtime-scripting limitation, and Roblox's 2026 chat age-gating policy — all added to `09-research.md` and `10-roadmap.md § Known Risks`. Seed system feasibility approach revised accordingly. **Not yet rescored.** |
| v5.2 | 2026-09-19 | Cleanup pass: registry corrected (next D54); README version synced; D23 attributed to R2 (not R1); stale D23 references fixed in 03/09; undefined "Vaultcore" corrected to Rift Core; "Epic material" removed; Riftshard defined as a Riftfall-only Component `[PROPOSED]`. |
| v5.3 | 2026-09-19 | Wrote the missing D54–D64 entries for the Q59–Q69 answers and propagated them (D58 broadcast queue, D59 wave cap, D60 tree UI, D61 crew invites, D62 directory, D63 seed prototype). Rule-leak fixes D65–D74: Robux cosmetics in a separate swap pool; raid band = highest of tier/lifetime peak/gear score; Blackout spares new-account shields; Scrap converts to a cosmetic currency at season end; NPC-sale Scrap removed; rebirth prestige-only, skip token cut; free Greenhouse raids; staggered T1/T2/T3 resets (supersedes D19); seeds foraged + cache packs; cosmetic rarity tiers. Proposed: Reputation tracks + Vaultbreaker Level, Level-10 trade gate, Marks, mob no-destroy. Q70 added. |
| v5.4 | 2026-09-19 | Locked D75–D106 (32 decisions) from the Part 1/2/3/4 discussion: 30-min shield exemption (D75), Tier 3 Fragment re-buy (D76), Prototype exempted from D33 wear-out (D77), blueprint announcement narrowed to Prototype (D78), sharding keyed to D66 band (D79), minimal bitpacking (D80), Reputation tracks locked (D81), Vaultbreaker Level + Level-10 trade gate locked (D82), season track free+premium (D83), Marks named and account-bound (D84), rarity names + Mythic rule locked (D85), rebirth deferred to S2+ (D86), mobs never destroy (D87), Greenhouse raid guardrails (D88), Robux-pool swaps confined to the direct trade window (D89), Crew Vault permissions (D90) and disband split (D91), gear score formula (D92), "Seed" roll renamed "Pattern" — resolves Q70 (D93), NPC price decay (D94), rare-seed vendor (D95), bounties (D96), trade-up contracts (D97), value-threshold trade holds (D98), word-bank Name Tags (D99), cosmetic-only pets for S2 (D100), raid escort in the slice (D101), bonus-only resonance nodes (D102), NPC contracts + Collection Log (D103), opt-in provenance tags (D104), raid log path map (D105), Community Beacon for S2 (D106). |
| v5.5 | 2026-09-19 | Slice locked for build. D107: final slice scope (resolves Q23) — adds raid escort and a minimal Level/Reputation gate; Workshop II/Fragments stay out; engineering estimate moved to build step 0. D108: slice-system sections locked (session structure, pickaxe tree, combat feel, gadgets, theft math structure, defenses, Tech Path structure/branches, crews split, Scav Waves, PvE ladder direction, loot table structure, success criteria, build order) and Q48 resolved. D109: starting values for crew tenure (24h) and respec refund (50%). Build phase docs added (`13-build-guide.md`, `14-claude-code-prompts.md`, repo `CLAUDE.md`). Stale items cleaned: Crew Vault note in 06, Q38 note in 02, secondary-detail list, next actions, Seed→Pattern leftovers, Season Plan now mentions the mid-season T3 reset, "defense XP" → Reputation. |
| v5.6 | 2026-09-19 | D110: the slice ships one craftable Harvester Drone for offline production (no Robux gamepass), resolving the build-order vs. out-of-scope contradiction; build step 12 unblocked. |
| v5.7 | 2026-09-20 | Build-phase decisions: D111 — pickaxes are not tradeable, pickaxe skins are (supersedes D21; 05/06/07 updated). D92 wording fixed — gear score counts pickaxe upgrade nodes, not Tech Path nodes. Placeholder XP→level curve added to `03-progression.md § Vaultbreaker Level`; Level is derived from XP (D80 note). D112 — armor added to the slice: craftable pieces, one chest slot, pickaxe tier names, knockback resistance + small damage reduction, spares stealable / worn never (R1), not tradeable (skins are); gear score adds highest owned armor tier. |
| v5.8 | 2026-09-21 | Build-phase answers: Mobility "sprint recovery" → "stun recovery" (the docs had no sprint); Scav Captain Signature drop = a Captain pickaxe skin; Vaultborn beam made faint/blinking/fading so it doesn't give away the strike spot; "contested" is a zone flag (Reaches, later the Rift; never the Homestead). |
| v5.9 | 2026-09-22 | Game renamed Vaultbreakers → Vault Raiderz; "Vaultbreaker Level" is now just "Level" (no title). |
| v5.10 | 2026-09-22 | D113: slice world layout "Main Street" (equal bridges, rotated plots, south plaza for NPC buyer + derelict FTUE vault; "concentric" wording loosened). D114: Chase escape = ~140-stud radius from the victim plot; a carrier who dies (incl. falling) drops loot home. |

## Next actions

The design is ready to build the slice. Remaining items, none of which
block starting step 0:

1. **Start the build** — `§ Build Order`, step 0, in Claude Code
2. Rescore v5.5 against the rubric (`01-pillars.md § Design rubric`) —
   last scored at v4; useful, not blocking
3. Resolve Q33/Q34 (boss loot distribution) before building Reaches-tier
   bosses (v1.0) — parked, does not affect the slice
4. Before v1.0: Marks conversion rate (D68), Blueprint Mastery vs.
   Advanced wear-out, Pattern visual prototype (D63)
