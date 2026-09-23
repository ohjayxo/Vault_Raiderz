# 04 — World Content

---

# THE PvE LADDER `[LOCKED direction — D108; slice ships Homestead tier only]`

**Why this exists:** without it there is nothing between "Scav Waves at
your base" and "Rift boss requiring a crew." That gap is fatal in a
45-minute session game.

One creature family per zone, scaling with the world's risk gradient.

| Zone | Mob | Boss | Group | Signature drop |
|---|---|---|---|---|
| **Homestead** | Scavs | **Scav Captain** (wave leader) | Solo | Common blueprints, gadgets, Standard Cases; **Captain pickaxe skin** (the Captain's Signature drop, name [PH]) |
| **Reaches** | Prowlers | **Reach Warden** (roams) | Solo/duo | Advanced blueprints, Grade-boosted rares, Rift Cases |
| **Deep Reaches** | Husks | **Glutton** (fixed lair) | Duo/trio | Advanced blueprints, first Unstable Finish chance |
| **The Rift** | Riftspawn | **Rift Bosses** (3 rotating) | Crew (3–4), **solo path exists** | **Prototype blueprints**, Rift Cores, elite Cases |
| **Beyond the Rift** | — | **World Boss** [PH — rare, e.g. weekly] | Server-wide | Seasonal-exclusive Prototype, unique cosmetic |

## Solo access to The Rift `[LOCKED — D27]`
Rift bosses are crew content by design, but **a solo path exists — much
harder, not gated out entirely.** A lone player can attempt a Rift boss
with sufficiently high gear and Mastery investment; the fight is
realistically survivable but punishing. This keeps the deepest content
from being purely a friendship-gate, while still making the crew path
the practical route for most players.

## Boss scaling `[LOCKED — D26]`

Bosses use a **soft group-size curve, not a hard gate:**

- A 4-person crew has a comfortably manageable fight.
- Difficulty rises **significantly** as the group shrinks toward solo —
  this is a real, steep curve, not a token penalty.
- **At the highest tier (Rift Bosses), a 1-person attempt is ~95% [PH]
  impossible** under baseline gear — but that percentage genuinely drops
  as the solo player invests in gear, Grade-boosted equipment, Mastery,
  and skill. Nobody is mechanically locked out; the door is just
  extremely narrow.
- The intent is explicit: **incentivize groups without making solo play
  impossible for players who simply can't find others to play with.**

## World Boss `[LOCKED — D28]`
A rare, server-wide event above Rift tier. Everyone on the server can
participate; the encounter is a genuine spectacle on a long cooldown
[PH — weekly or longer]. Drops a seasonal-exclusive Prototype and a
unique cosmetic unavailable anywhere else. This is intentionally rare and
expensive to build — it should feel like an occasion, not a routine.

## Why the ladder matters most for crews
Crew raids unlock only at high tier, meaning a new player otherwise has
no reason to make friends for hours. (Raid escort, D101, now gives
friends an earlier shared activity in the slice itself.) **The Glutton at duo/trio scale is
the on-ramp** — you need one other person, you learn to coordinate, and
by the time Rift bosses matter you already have people.

## Mobs vs bosses — different jobs

| | Purpose |
|---|---|
| **Mobs** | Make zones feel dangerous; provide a **PvP-free income floor**. Drop materials, gadget components, occasional low-tier Cases. Directly answers the pacifist-viability requirement. |
| **Bosses** | Events. Long cooldowns, telegraphed spawns, meaningful tables. Turn a session from "farm nodes" into "farm nodes, do the Warden, hit a Riftfall." |

## Loot table structure `[LOCKED — D108; odds PH]`

Every boss rolls across four buckets, not a single drop:

| Bucket | Odds [PH] | Contents |
|---|---|---|
| **Guaranteed** | 100% | Materials scaled to tier — killing it is never a waste |
| **Common** | ~60% | Cases, components, gadgets |
| **Rare** | ~25% | Blueprints of that tier (**visible on the ground before pickup** — `03-progression.md § Blueprint drops are visible before pickup`) |
| **Signature** | ~5–8% | The tier's identity item — the thing you farm for |

The guaranteed floor prevents the rage of a long fight yielding nothing.
The signature slot gives a weeks-long chase.

**Loot distribution to killer vs. ground, and instanced vs. shared among
a crew — still open** (`08-questions.md § Q33, Q34`) for Reaches-tier
bosses and above. **Not a slice blocker (D107):** the Scav Captain is
solo base-wave content, so its loot goes to the defending base owner.

## Bosses are PvP bait `[PROPOSED]`

Every boss above Homestead tier spawns in a **PvP-enabled zone**:

- The fight is PvE
- You are vulnerable during it and **visibly occupied**
- Your loot is in-transit afterward, subject to the full Chase rules
  (`02-core-loop.md § The Chase`)
- A crew that just spent four minutes killing the Glutton is at its
  weakest the moment it wins

**Third parties can profit without fighting the boss at all** — just camp
the exit. Emergent, entirely unscripted.

## Respawn cadence `[PH]`

| Boss | Cadence |
|---|---|
| Scav Captain | Appears in waves, no schedule |
| Reach Warden | ~20 min, multiple per server |
| Glutton | ~45 min, **one per server** (contested by definition) |
| Rift Bosses | 3 in rotation, one active, ~2 hr cycle, server-wide announcement |
| World Boss | Weekly or longer [PH] |

Escalating scarcity does the work: a Warden is routine, a Rift boss is an
event you plan around, a World Boss is an occasion.

**Seasonal hook:** each season swaps one Rift boss for a new one with a
fresh Prototype table.

---

# SCAV WAVES `[LOCKED — D108]`

Periodic NPC attacks on player bases.

**Why they earn their place:**
- Defenses have purpose even on quiet servers
- PvP-averse players get a complete loop
- **Teaches defense mechanics before a real player ever raids you**
- Successful defense yields resources + Reputation (`03-progression.md §
  Reputation tracks`, D81)

Scale waves to base tier. Failing one costs Exposed resources — a smaller
loss than a player raid. A pressure, not a punishment.

## Concurrent wave ceiling `[LOCKED — D59]`
A **server-wide cap on simultaneous Scav Waves**; overflow waves queue
with a short delay. A delayed wave is imperceptible to the affected
player; a framerate collapse mid-raid is not.

## Higher-tier mobs can raid too `[LOCKED — D29]`

**Scavs are not the only mobs that attack bases.** Higher-tier mobs
(Prowlers, Husks) can raid high-tier player bases as those players
advance into rougher content. This makes late-game defense meaningful
against PvE, not only against other players — a maxed-out builder who
never PvPs still has something to defend against.

**Mobs never destroy `[LOCKED — D87]`:** at vault tiers 8–10, mob raids
can knock a structure **offline**, but never trigger D23's permanent
destruction. Permanent loss is a price paid to a player who outplayed
you — not to an NPC.

---

# WORLD CACHES `[PROPOSED]`

The cheapest possible solution to "get players out of their comfort zone."

| Type | Visibility | Contents |
|---|---|---|
| **Standard Cache** | Visible, common, respawning | Common/uncommon resources with small Grade-odds boost, gadgets, components, **seed packs** (D73), ~5% Case |
| **Sealed Cache** | Hidden in genuinely obscure spots | Rare materials with guaranteed Grade boost, ~40% Case, occasional Blueprint, Fragments |
| **Static Secret** | Permanent, fixed, undocumented | Unique cosmetics, often fixed rare Pattern. One-time. |

### Why caches work
- Gives solo and PvP-averse players a reason to be in dangerous zones
- Rewards **map knowledge** — a skill that isn't reflexes, so it's
  accessible to younger players
- Makes the world feel authored rather than procedural

**Static Secrets are never documented by the developer.** The community
will make videos about them for years, which is free acquisition.

---

# DYNAMIC EVENTS `[PROPOSED]`

## Riftfall — the flagship event

Modeled on PUBG's airdrop logic: visible from a distance, disproportionately
valuable, and a trap.

- **Visible beam of light** across the map, not a text notification
- 60-second descent so everyone can converge
- **Tiered by zone:** Homestead soloable, Reaches contested, Rift-zone
  realistically needs a crew
- Contains a guaranteed **Riftshard** (`05-items.md § Components`),
  a Grade-boosted resource bundle, **plus** a rolled cosmetic
- **The twist:** opening takes a **15-second channel** [PH] that emits a
  loud, visible signal. You cannot quietly take it.

That channel converts "who got there first" into "who can hold it."

### Riftfall drop table [PH]
| Contents | Odds |
|---|---|
| Riftshard | Guaranteed |
| Resource bundle (boosted Grade odds) | Guaranteed |
| Rolled cosmetic | Guaranteed |
| Blueprint | ~25% |
| Sealed Case | ~15% |
| Fragment | Higher zones only |

Higher-zone Riftfalls upgrade every tier and add a guaranteed Case.

## Other events

| Event | Effect | Cadence [PH] |
|---|---|---|
| **Ion Storm** | Grade odds spike in one zone | 5 min duration, frequent |
| **Merchant Caravan** | NPC pays above market for one specific good — creates a real demand spike the market must react to | Occasional |
| **Blackout** | **All base shields drop server-wide for 10 min** — **except new-account shields, which never drop** (D67). Maximum tension. The "log in now" event. | Rare — once per few hours |
| **Rift Boss** | Crew-scale PvE, drops Prototype blueprints and Rift Cores | ~2 hr rotation |
| **World Boss** | Server-wide spectacle, drops seasonal Prototype | Weekly or longer [PH] |

**Event design principle:** events layer onto the existing loop, never
become separate modes. Grow a Garden's event restraint is the model —
new collection goals that keep the core loop intact.

## Micro-FOMO timers `[LOCKED]`

**NPC vendor stock rotates every 5 minutes** [PH].

Directly lifted from Grow a Garden, whose seed shop refreshes every 5
minutes, creating micro-FOMO moments where randomly appearing rare stock
turns each visit into a lottery ticket.

---

# FARMING `[LOCKED — ships at launch]`

A **Greenhouse** built on the player's plot. Plant → grows on a timer →
harvest. Intentionally simple; Grow a Garden proved this loop carries the
platform's biggest game with nothing more than buy seeds, plant, return
later, sell.

## Pure timer, no tending `[LOCKED — D41 (Q54)]`
Crops grow on a **pure timer with no watering/weeding requirement.**
Matches what already works on the platform (Grow a Garden) and stays
friendlier than an active-tending model that would reward only players
who can check in constantly.

## No crop is contested-zone-locked `[LOCKED — D43 (Q56)]`
**All crops, including future tea ingredients, are safe to grow
anywhere** on a player's own plot. No rare crop is restricted to the
Reaches or deeper zones. This keeps farming a fully safe, zero-combat
income path with no exceptions — the Riftsalt-style "you must go
somewhere dangerous" pressure is deliberately not applied here, since
farming's whole job is to be the safe alternative.

## Greenhouses are raidable separately from the Vault `[LOCKED — D42 (Q55)]`
A **dedicated, lower-stakes Greenhouse raid type** exists, distinct from
a full Vault raid. This is a gentler on-ramp for teaching the raiding
mechanic — the stakes of losing some crops are much lower than the
stakes of a full Vault breach, so it's a good place for newer or more
cautious players to experience being raided for the first time.

## Greenhouse raid cost `[LOCKED — D71]`
**Greenhouse raids cost no Breach Charges** — they are the free,
gentle on-ramp to raiding. When teas ship (S2), raids that can take
teas **do** cost charges.

**Guardrails `[LOCKED — D88]`** (R6 depends on raid cost, so a free raid
needs other brakes): matchmaking band and the 48-hour shield still
apply; a per-target cooldown [PH]; a daily cap per raider [PH].

## Seed sources `[LOCKED — D73]`
- **Wild plants scattered through the world** drop seeds when harvested
- **Seed packs** are a low-tier reward in World Caches
  (`§ World Caches`)

**Guardrail `[PROPOSED]` (D43):** every crop type must be obtainable
somewhere in the Homestead, even if rarer there than in the Reaches — no
crop may require entering a contested zone to acquire.

**Rare-seed vendor `[LOCKED — D95]`:** a small 5-minute rotating stock
of rare seeds for Credits, restoring the Credits sink that D73's
foraging-first model removed. Common seeds stay free to forage.

**Naming resolved (D93):** the collector roll is now called "Pattern,"
so crop "seeds" here are unambiguous (`08-questions.md § Q70`).

### What it adds
1. **A safe, zero-combat income path** — the strongest answer to
   pacifist viability
2. **Offline content with a visible state change** — you log in and *see*
   something happened. The best pull-back hook available.
3. **A raid target that isn't a number.** Growing crops sit Exposed by
   definition. Walking through a greenhouse of near-ripe high-value crops
   is far more visceral than stealing 400 ore.

### Integration
- Crops roll **Grades** like everything else (`05-items.md`), so a
  Prismatic harvest is a genuine event
- Crops are the ingredient supply for the deferred tea layer below
- Introduced early — intro tier, immediately after the FTUE

---

# TEAS / CONSUMABLES `[DEFERRED — Season 2+]`

**Deliberately withheld from launch** to preserve a major content drop
for the moment veterans start running out of things to do.

## The system when it ships

Brewed at a **Brewery**, unlocked at Workshop II+, from farmed
ingredients plus a resource input.

| May boost | May **not** boost |
|---|---|
| Mining yield | **Raw combat damage** |
| Grade odds | |
| Stamina | |
| Carry speed | |
| Crafting efficiency | |
| Healing rate | |
| Riftsalt yield | |

**R8 (`01-pillars.md`) is the load-bearing constraint.** Teas make players
richer and faster, not stronger in a fight.

## Duration scales with Workshop tier `[LOCKED — D44 (Q57)]`
Longer duration unlocks at higher Workshop tiers, giving veterans a
natural upgrade path within the consumable layer itself.

## Teas are always personal, never crew-shared `[LOCKED — D45 (Q58)]`
Unlike Tech Path nodes, a brewed tea buffs only the player who drinks it.
This keeps the veteran/newcomer reconciliation mechanisms (below) intact
— a shared crew buff would let one skilled brewer trivially boost an
entire crew, widening exactly the gap the reconciliation model is
designed to prevent.

## Hunger — `[CUT]`

Explicitly rejected. Hunger is a **punishment** mechanic — you lose
something for not doing a chore. Rust's audience accepts deprivation
because it is the genre's point; a young mobile audience experiences it
as nagging, and it punishes exactly the casual player the game can least
afford to lose.

Teas are a **reward** mechanic. Same content, inverted psychology.

**Baseline health regenerates on its own. No food requirement, ever.**

## The veteran/newcomer reconciliation `[PROPOSED]`

Five mechanisms; #3 does the real work.

1. **Teas don't compound.** Gear and Tech Path compound permanently. A
   tea is 10 minutes [PH], with duration scaling by Workshop tier (D44).
   The gap cannot widen indefinitely within a single dose.
2. **One active at a time.** Choosing *which* is the decision; stacking
   removes it.
3. **New players farm the ingredients — veterans buy them.** Farming is
   intro-tier; brewing is late-tier. The supply chain for the endgame's
   most desirable consumable is an *early-game activity*. **The veteran's
   advantage becomes the newcomer's paycheck.**
4. **Teas are perishable** (~48 hr [PH]). Nobody stockpiles an
   insurmountable buffer; demand stays constant and the crop market stays
   alive permanently.
5. **Teas are premium raid loot.** High value, fully stealable, not
   identity. A veteran brewing a stack before a boss run is a genuinely
   worthwhile target.

## What the tea layer fixes
- **Endgame gap** — top players get a production and logistics layer
- **Crew roles** — "the brewer" is a real job inside a crew, even without
  crew-sharing the output directly
- **Pacifist viability** — deepens the Greenhouse → market loop
---

# PETS `[LOCKED — D100; Season 2]`

**Not a booster system.** The standard Roblox pattern — Robux eggs
hatching random pets with stacking multipliers — was rejected: it's a
paid random item (R7), any luck-boosting item touching Robux must have
its odds numerically disclosed (conflicts with D46's hidden Grade odds),
and multipliers compound the exact veteran/newcomer gap D45 exists to
prevent.

**What ships instead, all cosmetic, no stat effect ever:**
- **Boss Pets** — an ultra-rare (Mythic-tier) cosmetic companion drop
  from bosses, rolling Condition and Pattern like any other cosmetic.
  Tradeable in the earned pool, never stealable (R1).
- **Case pets** — pets can appear as a Case reward. Credits-only, so
  this stays outside R7 entirely.
- **Tripwire Alarm skins** — a pet can skin the existing Tripwire Alarm
  defense (`02-core-loop.md § Defenses`) with no new AI or mechanic;
  purely a cosmetic reskin of a system that already exists.

**Never:** combat effects, Grade-odds boosts, yield multipliers, or
anything Robux-purchasable that touches odds.

---

# NPC CONTRACTS & COLLECTION LOG `[LOCKED — D103]`

**Contracts:** named Exchange NPCs offer daily and weekly contracts —
"deliver 50 Dense Ore to the Caravan" — paid in Credits and, for weekly
contracts, a small amount of Reputation (`03-progression.md § Reputation
tracks`). Cheap to build (they reuse existing resources and the existing
NPC-sale pipeline minus the Scrap faucet removed by D69) and a reliable
long-session hook.

**Collection Log:** a personal codex recording every distinct
cosmetic, Pattern range, Boss Pet, and drop-only item a player has ever
found — completion percentage as a visible flex stat, similar to the
Trophy Hall but comprehensive rather than curated. Costs almost nothing
new to build since it's a read of data the game already tracks.

Scope: v1.0.

---

# COMMUNITY BEACON `[LOCKED — D106; Season 2]`

The server **pools Credits** toward a threshold that triggers a Riftfall
or Ion Storm **early**. A genuine streamer moment — a server rallying
together to unlock a world event on demand — and a Credits sink that
scales with server population rather than any one player's wealth.

