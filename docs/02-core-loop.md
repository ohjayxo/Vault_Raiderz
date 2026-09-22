# 02 — Core Loop

---

## The loop in one line `[LOCKED]`

Tap glowing nodes → get resources → bank them or risk them → build your
Vault → raid someone or defend yourself → repeat, deeper.

---

# FIRST-TIME USER EXPERIENCE (FTUE)

**This is the highest-risk system in the game.** Over half of Roblox
games lose more than half their new players before Day 2, and the #1
cause of churn is a poor FTUE. Platform guidance: immediate action within
10 seconds, first reward within 60 seconds, clear objective at all times,
no walls of text, no forced tutorials.

Treat this section as a **spec**, not a description.

## FTUE spec `[LOCKED]`

| Time | Player does | System does | Text shown |
|---|---|---|---|
| 0:00–0:10 | Taps a glowing node | Spawns player facing node, pulsing arrow above it | **None** |
| 0:10–0:45 | Taps more nodes | Second node type appears; progress ring fills toward "BUILD VAULT" | **None** |
| 0:45–1:00 | Taps BUILD VAULT | Vault Core places with large visual payoff. **Free cosmetic granted.** | Button label only |
| 1:00–2:30 | Swings pick at a Scav | Scav NPC walks toward base; dies in 2–3 hits; drops loot | **None** |
| 2:30–4:00 | Observes | Banked/Exposed meter appears on HUD | **One line:** "Resources outside your Vault can be stolen." |
| 4:00–6:00 | Raids a derelict NPC vault | Guided, easy lockpick, guaranteed reward | Minimal prompt |
| 6:00+ | Free play | — | — |

### FTUE hard rules `[LOCKED]`

1. **No text before 2:30.** Arrows, glows, and animation only.
2. **First reward by 0:60.** The free cosmetic is not optional — it
   creates immediate ownership.
3. **PvE before PvP.** The player kills something before anything can
   hurt them.
4. **Their first steal is a win.** Framing theft as *fun* before it is
   ever framed as *threat* is the difference between delight and dread.
5. **Nothing from `03`, `04 § events`, `05 § cases/patterns`, or `06` is
   visible.** No market, no tech tree, no ranks, no crews, no cases.
6. **48-hour new-account raid shield** begins at first login. Blackout
   never drops it (`07-decisions.md § D67`). The **30-minute post-raid
   shield** carries the same exemption (`07-decisions.md § D75`).

---

# SESSION STRUCTURE `[LOCKED — D108; minutes PH]`

Target 45+ minutes (`01-pillars.md`). Five phases with different rhythms
so the player never fatigues on one activity. **The player is never told
this structure** — they discover the rhythm.

| Phase | Minutes [PH] | Activity | Intensity |
|---|---|---|---|
| Collection | 0–5 | Offline payout, bank, clear plot nodes | Low |
| Expedition | 5–15 | Reaches run for rare materials | Medium |
| Economy | 15–25 | Craft, list on market, reposition defenses | Low |
| Conflict | 25–40 | Raid, defend, or join a world event | High |
| Consolidation | 40–45+ | Bank, set offline production, check ladder | Low |

The loop **cycles rather than terminates** — a player having fun runs it
again.

**Pacing rule:** something notable must happen every 2–3 minutes [PH].

---

# WORLD STRUCTURE `[LOCKED]`

Floating archipelago. Four concentric zones, risk increasing outward.

| Zone | Contents | PvP | Raiding |
|---|---|---|---|
| **The Exchange** | Market, NPC vendors, public Workshop I, leaderboards, social hub | Off | — |
| **Homestead Ring** | Player plots, visible from the air | On | Yes |
| **The Reaches** | Contested rare nodes, Reach Warden, Glutton | On | — |
| **The Rift** | Legendary nodes, Rift bosses | On | — |

### Design notes
- Bases are **visually tiered from a distance.** Scouting a raid target
  is a visual skill, not a menu interaction.
- Fast-travel pads between zones (unlockable) so travel is never the
  boring part.
- One new resource is introduced per zone (`05-items.md § Resources`),
  so the economy teaches itself geographically.

## Server sharding `[LOCKED — D56, metric switched to D66 by D79]`
The Homestead Ring does **not** hold every player's plot in one shared
world per server. Servers host a bounded, **matchmaking-band-matched set
of plots** instead — using the same highest-of-tier/lifetime-peak/gear-score
metric as raid matchmaking (D66), not raw vault tier. **Why the switch
(D79):** raw vault tier let a rebirthed veteran land among neighbors they
could no longer raid, once D66 changed the raid band but not the shard
key. Cross-neighborhood scouting (seeing bases outside your own shard)
uses a lighter-weight map view rather than physically flying over every
plot on the server. This bounds how many persistent bases must be
simultaneously rendered, protecting the mobile render budget
(`09-research.md § Rendering & Mobile Performance Budget`).

---

# COMBAT `[LOCKED]`

## Melee only
No firearms. Two reasons: precision aiming is poor on mobile (the
majority of the audience), and firearms widen the moderation and age-
rating surface unnecessarily.

## The pickaxe is the weapon `[LOCKED]`
One item mines and fights. Consequences:
- A single upgrade path serves both playstyles — no dead-end investment
- A miner is never defenseless
- Every upgrade feels doubly valuable

**Tiers:** Wooden → Iron → Voltsteel → Riftedge

## Pickaxe upgrade tree `[LOCKED — D108]`
Each tier has 3 branches with limited points, so builds diverge:

| Branch | Upgrades |
|---|---|
| **Extraction** | Mine speed · Grade-odds bonus · multi-node strike |
| **Combat** | Swing speed · damage · knockback |
| **Mobility** | Carry speed (counters the loot slow) · stun recovery (shorter stuns and slows) · silent movement |

Same tool, three identities — and **readable**, because other players can
infer a build from how someone moves. Respec costs resources, never Robux.

## Combat feel `[LOCKED — D108; timings PH]`
- 3-hit combo, generous hitboxes, light aim assist, short knockback
- Fights resolve in 5–10 seconds [PH]
- Long fights punish mobile players and wreck pacing

## Gadgets `[LOCKED — D108; durations PH]`
Single-use, crafted or bought. Skill expression without twitch aim.

| Gadget | Effect |
|---|---|
| Smoke Bomb | Breaks line of sight, escape tool |
| Sprint Serum | 8s [PH] speed boost |
| Shock Trap | Throwable, brief stun |
| Disruptor | Disables one base defense for 15s [PH] |

---

# BANK vs EXPOSED `[LOCKED]`

**The single most important balance mechanic in the game.**

| State | Location | Stealable | Capacity |
|---|---|---|---|
| **Banked** | Inside Vault Core | **Never** | Capped, upgradeable (total units, all resources and Grades) |
| **Exposed** | Everything not yet banked, including overflow above cap | **Fully** | Unlimited |

Mined resources land in **Exposed**. The player banks them by using their
Vault Core, which moves them in best-first (highest Grade, then rarest
resource) until the cap is full; whatever doesn't fit stays Exposed.
Only Prismatic and Vaultborn skip the trip (§ Special cases).

### Why this carries so much weight
- Creates a live decision every session: *"I have 4,000 exposed — one
  more run, or bank now?"*
- Makes loss feel **self-inflicted**, not unfair. Anyone raided while
  overflowing knew the risk.
- Caps hoarding, which prevents economy inflation
- Creates the ideal Robux upsell: bank capacity sells **convenience**,
  never invulnerability (R3)

### Special cases `[LOCKED]`
- **Prismatic and Vaultborn grade items auto-bank on pickup** if
  capacity allows. Losing a 0.1% pull to a random raid is the single most
  likely event to make a player quit forever.
- **Research Scrap has its own separate, much smaller bank cap**
  (~20% [PH] of normal). Saving toward a big Tech Path node means sitting
  on an exposed pile for hours — deliberately recreating Rust's
  accumulation tension. (Confirmed — `08-questions.md § Q38`; the harsher
  unbankable variant was rejected.)

---

# RAIDING `[LOCKED]`

## Preconditions
- Raider must hold **Breach Charges**, crafted from **Riftsalt**, which
  spawns **only in contested zones** (`05-items.md § Resources`).
  Consequence: **you cannot be a safe farmer and a raider without paying
  someone who is.** Riftsalt is tradeable (`07-decisions.md § D20`), so a
  pure trader can now fund raiders without entering danger personally —
  the self-balancing pressure shifts from "raiders must farm it
  themselves" to "raiders must earn or buy it," which still keeps
  Riftsalt the most price-volatile good on the market.
- Target must be within the raider's matchmaking band — the **highest of
  current vault tier, lifetime peak vault tier, or gear score** (R6,
  `07-decisions.md § D66`). Gear score formula: `05-items.md § Gear score`.

## The raid sequence
1. Scout — bases are visually tiered, so target selection is visual
2. Breach — consume charges, enter
3. **Lockpick** — Skyrim-style: find the hidden sweet spot, 3 stages, difficulty scales with vault tier
4. Grab — take from Exposed only
5. **Escape** to the zone boundary within a 90-second window [PH]

## Lockpick skill model `[LOCKED]`
**High skill ceiling, expressed as speed — not success/failure.**
Everyone eventually gets in; skilled players get in *faster* and escape
before the owner reacts. This preserves accessibility for young/mobile
players while genuinely rewarding mastery.

## Theft math `[LOCKED structure — D108; all values PH]`

| Situation | Taken from Exposed | Notes |
|---|---|---|
| Online raid | 25% [PH] | Tier-scaled ceiling |
| Offline raid | **8% [PH]** | 30-min shield triggers after |
| Destroyed in transit | ~20% [PH] of stolen | **Currency sink — critical** |

**Loss is not 1:1.** The raider receives ~80% of what the victim loses.
The destroyed remainder is a primary economy sink — without it, raiding
merely circulates wealth and every number inflates to meaninglessness.

**Why offline is capped so low:** in Rust roughly 90% of raids occur
offline because it is safer, easier and more profitable — and the
resulting player frustration is extensively documented. The incentive
gradient must actively push toward online raids, or offline becomes the
dominant strategy and the world empties out.

---

# THE CHASE `[LOCKED]`

The most important emergent moment in the game. Modeled on the mechanic
proven in Steal a Brainrot, where a thief carrying an item is slowed,
stripped of items, and the owner alerted — and attacking the thief
returns the item to its base.

When a raider grabs loot:

1. **Movement speed drops sharply**
2. **Gadgets disabled** while carrying
3. **Owner alerted instantly** — including offline, via raid log
4. **Raider visibly marked server-wide** with a loot trail
5. **Any player who lands a hit** knocks the loot loose; it returns to
   the owner's vault

**Point 5 is the key design choice.** Third parties can intervene. A raid
is not victim-vs-thief, it is a **server-wide event anyone can profit
from or crash**. That is the clip that ends up on TikTok, and it is free
marketing.

## Raid escort `[LOCKED — D101; in the vertical slice]`
A friend can accompany a solo raider and **body-block interceptors
during the Chase** — they can't carry or grab loot themselves, only
physically get in the way of anyone trying to land the hit that knocks
loot loose (point 5 above). This gives early friend play something to
do together without touching D4's crew-raid tier gate: it's a bystander
role during someone else's solo raid, not joint raiding.

## Raid log path map `[LOCKED — D105]`
The raid log (point 3 above) includes a **path-line map** of the
raider's route through the base — not a full replay, just the line they
walked and where they triggered defenses. Cheap to render, gives the
victim something concrete to react to ("how did they get past my
gate"), and is exactly the kind of clip a streamer screenshots.

## Resonance nodes `[LOCKED — D102]`
A resource node type that **two players mining it simultaneously**
yields boosted Grade odds for both. **Strictly a bonus, never
required** — a solo player mines it fine at normal odds; the boost
exists to give friends a reason to mine side by side, not a wall solo
players hit. Scope: v1.0.

---

# HUD PRIORITY `[LOCKED — D64]`

A raid can coincide with a Scav Wave, a defense-charge readout, and the
Chase's loot-trail marker — all needing to be readable at a glance on
baseline mobile hardware. These surface through **one compact,
priority-ordered "threat strip"** rather than one independent HUD
element per system, queueing whichever alert is lower-priority.

**Why:** a defender who can't parse a stacked phone screen fast enough
isn't meaningfully defended regardless of server fairness (R5). Detailed
layout is a build-phase UI spec item; the priority-strip principle is
locked now.

---

# DEFENSES `[LOCKED — principle and defense list, D108]`

**Principle: defenses delay and detect. They never hard-block.**
An unraidable base breaks the loop for everyone.

| Defense | Effect |
|---|---|
| Tripwire Alarm | Alerts owner + marks intruder |
| Spike Floor | Slows movement in a zone |
| Shock Fence | Brief stun on contact |
| Decoy Vault | Wastes ~20s [PH] of the 90s window |
| Guard Drone | NPC harasser |
| Lock Upgrade | Increases lockpick difficulty |

- **Limited defense slots** — defense is a loadout puzzle raiders can
  read and counter, not a turret wall.
- Defenses run on **charges** that deplete when triggered and cost
  resources to refill. Another sink, and a reason to log in.

---

# BASE / HOME `[LOCKED]`

Physical, visible growth. Tier 1 wooden shack → Tier 10 fortified
floating compound.

## Buildable elements
- **Vault Core** — bank capacity + raid difficulty
- **Walls & Gates** — path control, funnels raiders into defenses
- **Workshop I/II/III** — research and crafting (`03-progression.md`)
- **Greenhouse** — farming (`04-world-content.md § Farming`)
- **Defense slots** — limited
- **Trophy Hall** — walkable display of rare finds
- **Decor** — free-form cosmetic placement

## Build budget `[LOCKED — D57]`
Every buildable element above, **Decor included**, counts against a
tier-scaled piece/draw-call budget enforced at placement time. Decor was
the one category with no stated limit and the likeliest source of a
single plot blowing the shared render budget for every visible neighbor
(`09-research.md § Rendering & Mobile Performance Budget`). Higher vault
tiers get a larger budget, matching the natural growth of a base as it
climbs tiers.

## Ally Pass `[PROPOSED]`
Designate trusted players who enter without triggering alarms. Borrowed
from Steal a Brainrot's Friend Controller concept. Turns a base into a
social space rather than purely a fortress.

## Tiered raid interaction `[LOCKED — D23]`

| Vault Tier | What a raider may do |
|---|---|
| 1–4 | Steal Exposed resources only |
| 5–7 | Steal + knock one defense or Workshop **offline** 15 min [PH], free repair |
| 8–10 | Steal + **permanently destroy one targeted structure** per successful raid |

Tiers 1–7 keep R2 fully intact — nothing lost but time and momentum.
**Tiers 8–10 are the one exception to R2** (`01-pillars.md § R2`):
"damage, never destroy" was judged too soft for elite play, so the top
band allows real, permanent structural loss. High-tier players opted
into this by climbing; new players never encounter it. Cosmetics and
equipped gear are never destroyed at any tier — R1 always wins.
(`07-decisions.md § D23`)

## Plot lifecycle `[LOCKED — D55]`
A plot inactive past ~1 year [PH] **archives to compressed cold storage
and restores fully when the player returns.** This is hibernation, not
deletion — R2's "nothing lost" promise holds in spirit — and it gives the
DataStore storage cap (`09-research.md § Data Architecture`) real
headroom as the lifetime player count grows. Active plots are never
touched by this rule.

---

# AUTOMATION `[LOCKED]`

- Manual tapping to start — the most immediately satisfying action available
- **Harvester Drones** (crafted or Robux gamepass) enable offline production
- **Offline production is mandatory, not optional.** Grow a Garden's
  dominance rests on plants growing offline, guaranteeing fresh content
  every login. Steal a Brainrot also accrues offline income at a reduced
  rate. Every login opens with a "while you were away" payout.
- **Fairness rule (R3):** automation is always slower per minute than
  active play at equal investment.
- **Slice scope (D110):** the vertical slice ships **one craftable
  Harvester Drone** and no Robux gamepass version.
