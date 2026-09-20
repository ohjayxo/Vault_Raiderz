# 09 — Research & Sources

Everything here was gathered during design (Sept 2026). **Platform policy
and market conditions move fast — re-verify anything policy-related
before building against it.**

---

# PLATFORM LANDSCAPE (2026)

| Game | Scale | Genre | Relevance |
|---|---|---|---|
| **Brookhaven RP** | ~83.7B visits, most-visited ever | Roleplay sandbox | Social stickiness beats mechanics |
| **Grow a Garden** | ~35.3B visits; biggest by daily CCU in 2026 (~1.0–1.2M); 21.3M peak CCU; fastest to 1B visits (33 days) | Farming sim | **Primary model for offline growth + mutations** |
| **Steal a Brainrot** | All-time CCU record 25.8M (Oct 2025) | Theft tycoon | **Primary model for theft tension** |
| **Blox Fruits** | ~52.9B visits, ~300K consistent CCU | Action RPG | Deep-session lane |
| **Adopt Me** | ~531K CCU (Apr 2026) | Pet trading | Trading economy longevity |
| **99 Nights in the Forest** | ~442K CCU | Co-op survival | Deep-session lane |

**Two dominant 2026 trends:** fast meme-driven titles pulling millions
within days, and deep long-session experiences at 45+ minutes per session.
Vaultbreakers targets the second lane with the first lane's hook.

---

# GROW A GARDEN — what to copy

The entire game: visit the seed shop, buy seeds, plant, return later to
harvest and sell. No tutorial, no onboarding, no friction. Beneath it:

| Mechanic | Effect | Our adaptation |
|---|---|---|
| **Plants grow offline** | Guarantees fresh content every login | Offline production is mandatory (`02-core-loop.md`) |
| **5-min shop refresh** | Micro-FOMO; rare stock makes each visit a lottery ticket | Vendor rotation (`04-world-content.md`) |
| **Mutations** | Alter look *and* value; weather/pet/event triggered; stacking multipliers; Rainbow = 0.1% for 50× | **The Grade system** (`05-items.md`) |
| **Event restraint** | New collection goals keeping the core loop intact, not separate modes | Event design principle |

Also notable: ~35% of its player base is under 13. Design accordingly.

**Caution:** the game faced allegations of bot activity inflating
algorithm visibility, with time-limited items incentivizing bot
collection. Roblox's own analysis attributed growth to genuine
popularity. Relevance: **time-limited items attract bots.**

---

# STEAL A BRAINROT — what to copy, what to avoid

## Mechanics worth taking

- **The chase:** a thief carrying an item is slowed, stripped of items,
  and the owner is alerted; attacking the thief returns the item to its
  base. Thief is at maximum vulnerability exactly when holding the most.
- **Base lock:** 30s on join, re-lockable for 60s; each rebirth adds 10s.
  Rebirth increasing safety is elegant.
- **Friend Controller:** trusted players bypass lock lasers without
  triggering alerts → our **Ally Pass**.
- **Offline income** accrues at a reduced rate.
- **Defense is positional:** valuable items placed deep buy reaction
  time; layout matters more than raw gear.

## Criticisms — our roadmap

| Criticism | Our counter |
|---|---|
| **Pay-to-win** — best items only for cash, including purchasable server-admin abilities (Polygon) | R3 + D15 |
| **Cheaters** — automation scripts for cash collection and stealing (GameRant) | R5, server authority from day one |
| **Shallow long-term** — buy, wait, steal, rebirth | Economy depth, Tech Path, seeds |
| **Emotional intensity** — documented distress in young players when items are stolen | R1, R2, R6, auto-bank protection |

---

# RUST — the cautionary tale and the good mechanics

## The warning

**~90% of raids occur offline** because it's safer, easier and more
profitable. Player sentiment is documented and severe — threads about
being raided seven days running, arguments that easy raiding kills server
populations because people don't return after being raided and griefed.

**Lesson:** the incentive gradient must actively push toward online
raids. Hence D1's 8% cap.

## Mechanics adopted

| Rust mechanic | Detail | Our version |
|---|---|---|
| **Raid cost calculus** | Raiders weigh explosive cost vs loot; defenders honeycomb to become a bad investment | Breach Charges |
| **Workbench tiers** | WB1 50 scrap, WB2 500, WB3 1,250 — 1,800 total; each must be placed next to the previous | Workshop I/II/III |
| **Low bench HP** | WB2 500 HP, WB3 750 — a prime raid target destroyed in seconds | Workshop knocked offline at vault tiers 5–7; permanently destroyable at 8–10 only (D23) |
| **Blueprint Fragments** | Post-Meta-Shift, T2/T3 benches gated by loot-only fragments, pushing progression from solo farming to contested monument runs | Core/Rift Fragments |
| **Research Table** | Consumes item + scrap → permanent blueprint. "A looted Thompson is one gun; a researched Thompson is every Thompson" | Research Bench |
| **Tech Tree** | Per-bench trees, prerequisite paths, ~20–500 scrap/node, ~10,820 total for 285 items; almost nobody clears a tier | Tech Path |
| **Experiment** | Random blueprint from that tier, ~75/300/1000 scrap | Experiment |
| **Public research table** | Free at Outpost — how most solos bank their first BP | Public Workshop I |
| **Uncraftable components** | Springs, gears, tech trash have no recipe; why monument running matters | Components |
| **Workbench access trading** | Players trade bench access for materials | Workshop rental |
| **Four resources** | Stone / metal / HQM (scarce trickle) / sulfur (raiding only) | Stone / Ore / Voltstone / Riftsalt |

## Mechanics rejected
- **Decay / upkeep** — a TC running out of materials decays the base tier
  by tier. Punishing players for not logging in is correct for Rust,
  catastrophic for a young Roblox audience.
- **Structure destruction at vault tiers 1–7** — crosses the identity
  line. Allowed only at tiers 8–10 (`07-decisions.md § D23`).

---

# CS2 — the seed/float system

- **Float (wear)** and **pattern index (paint seed)** are rolled
  independently; neither constrains the other. A Factory New item can
  have an unremarkable pattern; a Field-Tested one can be a top-tier seed.
**Terminology note:** this section discusses CS's own "Seed" concept and
our system's pre-D93 name for it; the field is called **Pattern** in the
rest of the doc set (D93). Left as "Seed" here for direct CS comparison.

- Seed is an integer **0–1000** assigned at creation, deciding where the
  texture lands on the model.
- **Only pattern-sensitive finishes matter.** For uniform textures,
  shifting placement changes nothing noticeable — which is why seed is
  irrelevant on most skins.
- **Scarcity math:** ~1,000 seeds; on a finish like Case Hardened maybe a
  dozen produce a truly blue result, making a top-seed copy scarcer than
  a low float that any number of copies can share.
- **Value hierarchy is community-generated**, reflecting what collectors
  catalogued over years — not official Valve data. Seed #661 became the
  "Blue Gem" because players decided it did.

**Why this matters commercially:** ship 10 skins, get 10,000 community
conversations. Free, infinite, player-authored content.

---

# RETENTION BENCHMARKS

| Metric | Benchmark |
|---|---|
| D1 retention — decent | 20%+ |
| D1 retention — great | 30%+ |
| D1 retention — top | 40%+ |
| Genre note | Simulators retain better than single-session genres |

**Stakes:** over 80% of lifetime revenue comes from players who survive
the first week — yet most Roblox games lose more than half their new
players before Day 2. The #1 churn cause is a poor FTUE.

**Platform FTUE guidance:** immediate action within 10 seconds, first
reward within 60 seconds, clear objective at all times, no walls of text
or forced tutorials.

**What lasts longest** (cross-game observation): social hooks where the
social experience matters more than mechanics; player-to-player trading
economies; constant updates; PvP layers keeping content from going stale;
and a low barrier to entry — complex games filter players out.

---

# PLATFORM POLICY — Chat & Social Age-Gating `[NEW — verify before building social UI]`

As of 2026, Roblox requires an **age check to access chat at all**
(facial age estimation, ID verification, or parental controls), and
communication between age brackets is restricted by default —
adult-minor chat is limited to Trusted Connections, and **experience
chat is off by default entirely for users under 9**, requiring a parent
to manually enable it. This rolled out globally through early-to-mid
2026, driven partly by state-level lawsuits alleging inadequate minor
protection.

**Why this matters here:** several Vaultbreakers mechanics lean on
players being able to actually talk to each other — crew coordination
when splitting the Tech Path (`03-progression.md § Crews`), the
deliberately "manual, trust-based" Workshop III rental interaction
(`03-progression.md § D24`), and general market negotiation. None of
these mechanics *require* chat to function — trading, crew invites, and
raiding all resolve through game systems, not conversation — but the
social texture the design leans on for feel (trust, negotiation,
coordination) may be quieter than intended for a meaningful share of the
target audience, particularly the under-9 segment `01-pillars.md`
explicitly names as a meaningful share of players.

**Action:** design crew and trade interactions to work entirely without
chat — icon-based requests, preset trade offers, a simple non-verbal
"invite to crew" flow — rather than assuming conversation will carry the
social layer. See `10-roadmap.md § Known Risks` for this added as a
tracked gap.

---

# PLATFORM POLICY — Paid Random Items `[VERIFY BEFORE BUILDING]`

Roblox requires that for paid random items purchased with Robux — **or
indirectly via in-game currencies purchased with Robux** — all possible
outcomes and their actual numerical odds be displayed, summing to exactly
100%. The policy explicitly names spending Robux on keys to open boxes as
a covered example.

Roblox updated its Community Standards and documentation for Paid Random
Items in **May 2026**, describing them as a highly regulated mechanism
legally prohibited for certain users. The change came from complying with
South Korean game law and was rolled out globally rather than building a
Korea-only version. Developers on the forums expressed concern that most
simulator games on the platform currently violate it.

**Our position (D15, D65):** Credits are not Robux-purchasable at any
remove, and Robux-bought cosmetics trade only inside their own swap pool,
so no good bought with Robux can reach Credits, Keys, or Cases. Both are
required — the policy covers random items bought with Robux **or with
goods purchased using Robux**.

**Re-verified 2026-09-19** (Roblox Creator Hub paid-random-items
documentation; May 2026 DevForum announcement). Also relevant for any
future pet or booster idea: **paid items that improve the odds of other
random outcomes must have their effect numerically explained** — which
conflicts with D46's hidden Grade odds. Any Robux-touching luck boost is
therefore off the table.

---

# TECHNICAL — cross-server architecture

**Confirmed feasible.** Roblox documents **cross-server trading and
auctioning** as a primary MemoryStoreService use case — universal trading
between servers with real-time changing prices via a sorted map — and
notes memory stores support permanent features like a global marketplace
where the marketplace persists but listings expire.

## The MessagingService constraint

MessagingService allows roughly **150 messages/minute per server** and
**60/minute per topic**, payloads capped at **1KB**, with **no delivery
guarantee**. The most common cross-server bug is studios broadcasting
economy events over it and assuming delivery — when quota saturates,
messages drop silently with no error.

**Required pattern:** MemoryStore is the authority; MessagingService is a
hint that state changed; servers reconcile against the store on a 30–60
second interval.

## MemoryStore limits (verified 2026) `[UPDATED]`

Roblox replaced the old per-structure limits with a single **per-
partition throttle** — generally far more generous than the old model,
especially for hash maps, since hash map requests spread across
partitions by key. **But an individual item key is still rate-limited**
if most traffic targets it directly — the mitigation is key sharding:
spread reads/writes across multiple keys rather than hammering one
"global price list" key. Good news for the market design overall; just
don't centralize all market activity onto a single MemoryStore key.

Also note: MemoryStore eviction is not guaranteed for its full window
under memory pressure. Durable data belongs in DataStore.

---

# DATA ARCHITECTURE — DataStore's 2026 restructure `[NEW — verify before building]`

**This changed materially since earlier drafts of this doc and directly
affects the persistent-plot, global-market design.**

Roblox moved DataStore from a **per-server budget** to a **single shared
pool per experience** — every server of your game now draws from one
combined request budget and one combined storage allocation, rather than
each server having its own independent quota. Alongside this, there is
now a **hard total storage cap per experience**: baseline 500 MB plus
1 MB per lifetime player, effective July 2026.

**Why this matters here specifically:** Vaultbreakers' core design
assumes persistent plots for every player, forever (`07-decisions.md §
D6`), plus a global cross-server market. That combination is exactly the
unbounded-growth pattern the new cap is built to catch. A genuinely
successful game accumulating hundreds of thousands of lifetime players
will need active data hygiene — compressing payloads, archiving or
pruning long-inactive plots, expiring stale market listings — as a
first-class architectural decision, not a later cleanup pass.

**Minimal bitpacking now `[LOCKED — D80, revises D54]`:** D54 deferred
payload compression generally, but v5.3 added several new small
per-item/per-player flags (Robux-pool marker, market-acquired flag,
lifetime peak tier, Vaultbreaker Level, Reputation values). These are
bitpacked from the start as cheap insurance — full payload compression
for the larger, more complex fields (Tech Path state, raid logs) still
waits for real usage data per D54.

**This is not fatal**, but it changes the "build order" item in
`10-roadmap.md § Build Order` — the server-authoritative data layer needs
a data lifecycle policy designed in from the start, sized against this
formula, not assumed to be unlimited.

---

# RENDERING & MOBILE PERFORMANCE BUDGET `[NEW — concrete numbers available]`

Previously flagged in `10-roadmap.md § Known Risks` as "not yet set."
There's now a real target to design against.

| Constraint | Limit (2026) |
|---|---|
| Scene-wide draw calls (baseline device target) | ~1,000 |
| Scene-wide triangles (baseline device target) | ~1,000,000 |
| Triangles per MeshPart (hard import cap) | ~20,000–21,000 |
| Triangles per UGC accessory | ~4,000 |
| Diffuse/PBR texture resolution | 1024×1024 max |

**Why this is tight for Vaultbreakers specifically:** the design leans on
visually scouting neighboring bases from a distance as a core mechanic
(`02-core-loop.md § World Structure`). That means the rendering budget
has to simultaneously cover your own base, every visible neighboring
base, active Grade particle effects, and any procedural Seed cosmetics —
all inside the same ~1,000 draw call / ~1,000,000 triangle ceiling, on a
phone. LOD (level-of-detail) and occlusion culling on neighboring bases
are not optional polish here; they're load-bearing for the core loop to
run at all on the target hardware.

**Action, unchanged from before but now with a real number to hit:** set
this budget before building, prototype base-density scenes early, and
test on a genuinely low-end device rather than in Studio on a desktop.

---

# NO CUSTOM SHADERS — confirmed, with a sharper caveat for the Seed system `[UPDATED]`

Roblox still has no custom shader pipeline (confirmed current as of
2026; a CPU-based primitive shader path via `EditableImage` is in
development but not shipped). This was already known and drove the
"reliable fallback" recommendation in `05-items.md § Seed`.

**The sharper finding:** `SurfaceAppearance` properties — the actual PBR
texture maps that would drive UV-offset or overlay-layer swapping —
**generally cannot be modified by script at runtime at all**, because the
engine requires pre-processing to display them. **The one confirmed
exception is `SurfaceAppearance.Color`, a live-tintable property.**

**Consequence for the Seed implementation:** hue/tint-driven seed
variation is confirmed technically doable at runtime. UV-offset and
overlay-layer selection — the other two levers proposed in the reliable
fallback — likely are **not** achievable through live script changes to
SurfaceAppearance. The practical alternative is a **pre-baked set of
discrete texture variants selected by seed bucket** (e.g., seed 1–200
uses texture variant A, 201–400 uses variant B, with tint layered on
top) rather than continuous per-seed procedural manipulation. This
sharpens, but does not remove, the existing "needs a Studio prototype
before promising the ambitious version" flag.

---

# OPEN RESEARCH GAPS

Things not yet investigated that should be before building:

1. **Roblox runtime image manipulation** — capability and mobile
   performance, for the ambitious Seed implementation (`05-items.md`)
2. **Mobile draw-call budget** — persistent plots + visible bases +
   Grade particle effects + procedural seeds
3. **Social safety tooling** — moderation approach for a young audience
   with trading and crews
4. **Market manipulation defenses** — wash trading, alt farming
   (`06-economy.md § Market manipulation`)
5. **Current Roblox DataStore/MemoryStore rate limits** — exact figures
   at the scale this design implies
