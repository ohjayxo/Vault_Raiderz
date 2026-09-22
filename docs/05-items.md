# 05 — Items

---

# TAXONOMY `[LOCKED]`

Every item type, with its economic role and loss rules.

| Category | Rolled? | Tradeable | Stealable | Role |
|---|---|---|---|---|
| **Resources** | Grade | Yes | Yes (Exposed) | Economy fuel |
| **Components** | No | Yes | Yes | Crafting gate — loot only |
| **Gadgets** | No | Yes | Yes | Consumable sink |
| **Breach Charges** | No | Yes | Yes | Raid cost sink |
| **Gear / Pickaxes** | No — a per-player tier, not an item | **No — D111** | **No** | Power (skins carry the flex — see Cosmetics) |
| **Armor** | No — tier fixed when crafted | **No — D112** (armor skins trade) | **Spare pieces: yes · worn piece: no (R1)** | Defense + a loss stake |
| **Cosmetics** | Rarity tier + Condition + Pattern | Earned: yes · **Robux-bought: swap-only, Robux pool (D65)** | **No** | Pure collector layer |
| **Blueprints** | No | Tiered — see `03-progression.md` | Yes (unlearned) | Knowledge scarcity |
| **Cases** | Contents hidden | Yes | **Yes (sealed)** | Speculation good |
| **Keys** | No | Yes | Yes | Case sink |
| **Fragments** | No | **Yes — D22** | Yes | Workshop gate |
| **Research Scrap** | No | **No** | Yes (above small cap) | Progression currency; converts to a cosmetic-only currency at season end (D68) |
| **Crops** | Grade | Yes | Yes (growing = Exposed) | Safe income + tea input |
| **Seed packs** | No | Yes | Yes (Exposed) | Farming input — foraged or cache loot (D73) |

**The governing split (R1):** anything carrying identity is never
stealable. Anything fungible or sealed is. Gear is neither tradeable nor
stealable (D111): the pickaxe is your tier, not an item. What trades is
its look — pickaxe skins are cosmetics.

---

# RESOURCES `[LOCKED]`

**Four resources, each with a genuinely different job.** This replaces an
earlier nine-resource model where every resource meant the same thing —
"higher tier = better" — which is a single ladder wearing nine costumes
and contains no decisions.

Modeled directly on Rust's stone/metal/HQM/sulfur structure.

| Resource | Rust analog | Source | Used for | The decision it creates |
|---|---|---|---|---|
| **Stone** | Stone | Homestead plot, abundant | Base structure, walls, storage | How much do I fortify? |
| **Ore** | Metal frags | Homestead + Reaches | Tools, Workshops, defenses, gear | Gear up or build up? |
| **Voltstone** | HQM | **Small trickle from Ore nodes**; rich nodes in the Reaches | Elite gear, Workshop III, top defenses, **high-tier base upgrades (D40)** | What do I spend my tiny supply on? |
| **Riftsalt** | Sulfur | **Contested zones only**; **tradeable (D20)** | **Breach Charges — raiding, nothing else** | Do I raid, or fund a raider, or keep farming? |

## The Riftsalt rule `[LOCKED, with D20 amendment]`

**"Contested" is a zone property:** the Reaches (and later the Rift) are contested; the Homestead never is, even though PvP is on there. The server refuses a Riftsalt spawn anywhere else.

**Raid material spawns only in contested zones**, but **Riftsalt is
tradeable** (`07-decisions.md § D20`). Therefore:

> **You cannot be a safe farmer and a raider — but you can be a safe
> farmer who funds one.**

Consequences:
- Raiding still requires someone to personally expose themselves in
  contested zones — the supply doesn't create itself
- But a pure Trader or safe Miner can now buy Riftsalt and either resell
  it or gift it to a raiding crewmate, creating a genuine arms-supplier
  role that didn't exist in the untradeable version
- Riftsalt is the most price-volatile good on the market, spiking
  whenever raiding heats up — now with actual price discovery instead of
  being purely personal-use
- **R6 protection is unaffected:** raid *cost* and vault-tier matchmaking
  still gate who can be targeted, regardless of how a raider got their
  Riftsalt

## Voltstone at high tiers `[LOCKED — D40 (Q51)]`

**Base upgrades at high vault tiers require Voltstone**, not just Ore and
Stone. This closes the "never leave home" loophole — even a pure builder
who never fights or trades still has to make at least one trip to the
Reaches (or buy Voltstone from someone who did) to keep upgrading past a
certain point.

## Rich-node landmarks `[LOCKED — D39 (Q50)]`

**Voltstone rich-nodes announce themselves** — a visible glowing
landmark in the Reaches, similar in spirit to a mini-Riftfall. This
converts them into contested points other players will actively fight
over, rather than a quiet reward for exploration.

## Node respawn: depletion, not fixed timers `[LOCKED — D38 (Q52)]`

Resource nodes in the Reaches and deeper zones **deplete and migrate**
rather than respawning on a predictable clock. This forces continuous
re-exploration instead of letting players settle into a static farming
route — at the cost of frustrating players who prefer routine. Homestead
nodes (the FTUE-tier resources) are exempt and keep fixed respawns, since
predictability matters most exactly where new players are learning the
loop.

## The Voltstone trickle `[LOCKED]`

Voltstone arrives in **small amounts as a byproduct of ordinary Ore
nodes**. Every node has a whiff of the good stuff — you are never mining
"just stone."

**Stacks with Grade:** a Volatile-grade Ore node paying 10× is a
meaningful Voltstone windfall. The two systems multiply rather than
compete.

## Progressive reveal `[LOCKED]`

One resource per zone, each arriving attached to a goal the player
already has (R4):

| When | Resource | Why it lands |
|---|---|---|
| Minute 1, Homestead | Stone | That's the whole economy |
| Minute ~5 | Ore | Now there's a build-vs-craft decision |
| First Reaches trip | Voltstone | Scarce, exciting, tied to danger |
| When they decide to raid | Riftsalt | They go looking because they already want something |

Nobody is ever handed four resources and a spreadsheet.

---

# THE THREE RARITY ROLLS `[LOCKED]`

**Three independent rolls, clean separation.** Grade drives the
**economy**; Condition and Pattern drive **collecting**. They never interfere
with each other, and none of them ever touches game balance.

## Roll 1 — GRADE (resources & crops) — *value*

The Grow a Garden mutation analog. Grow a Garden's mutations alter both
look and value, triggered by weather/pets/events, with stacking
multipliers — a Rainbow is a 0.1% chance for 50× value.

| Grade | Odds [PH] | Multiplier [PH] | Visual |
|---|---|---|---|
| Standard | 85% | 1× | Plain |
| Dense | 10% | 3× | Faint shimmer |
| Volatile | 4% | 10× | Crackling |
| **Prismatic** | 0.9% | 50× | Rainbow, visible across the map |
| **Vaultborn** | 0.1% | 200× | Faint, blinking, fading beam (easy to miss at a glance, spottable by a watchful player), **server-wide announcement** |

### Odds are not published in-game `[LOCKED — D46 (Q15)]`
The table above stays internal. Hiding exact odds creates community wiki
culture and mystery, which fits the genre's discovery-driven appeal.
Credits are gameplay-only, so this is a free choice, not a compliance
requirement (`06-economy.md § Platform policy`) — Roblox's disclosure
rule applies to Robux-touching randomness, and nothing here touches
Robux.

### Why Grade carries so much
- Every tap is a lottery ticket
- A Prismatic pull is a **moment** — screenshot-able, clip-able
- Vaultborn's announcement creates instant social drama
- Gives the market something real to price
- Infinitely extensible (new Grades, event-only Grades) with **no new systems**

### Vaultborn announcement `[LOCKED]`
**Zone-level, not coordinates.** *"A Vaultborn strike was detected in the
Eastern Reaches."* Holder gets ~30 seconds [PH] of head start.

The beam at the strike is deliberately faint and blinking, so it doesn't give away the spot the announcement hides, unless someone is watching closely.

**Signal decay `[PROPOSED]`:** narrows zone → sub-region → approximate
position over 2 minutes [PH] if the holder stays in the open. Bank it
fast, or go dark. Converts a passive announcement into an active chase
with a clock.

### Environmental modifiers `[PROPOSED]`
Zone conditions temporarily boost Grade odds (Ion Storm doubles Volatile
in the Reaches). Makes being online during events genuinely valuable and
spikes contested-zone traffic on a schedule.

### Auto-bank protection `[LOCKED]`
Prismatic and Vaultborn **auto-bank on pickup** if capacity allows.
Losing a 0.1% pull to a random raid is the likeliest single event to make
a player quit forever.

## Roll 2 — CONDITION (gear & cosmetics) — *the float analog*

A 0.00–1.00 value assigned at creation, banded:

`Pristine · Clean · Worn · Scarred · Ruined`

**Purely cosmetic. Does NOT affect stats.** The moment Condition affects
performance, you have built pay-to-win-by-luck.

## Roll 3 — SEED (gear & cosmetics) — *the pattern analog*

An integer **1–1000**, assigned at creation, **permanent, never
re-rollable.**

### The critical rule — only some skins are seed-sensitive

In CS2, the pattern index decides where a texture lands on the model. For
a uniform texture, shifting it changes nothing noticeable — which is why
seed is irrelevant on most skins. But on pattern-sensitive finishes it
can be worth more than everything else about the item combined.

The scarcity math: there are only ~1,000 seeds, and on a finish like Case
Hardened maybe a dozen produce a truly blue result — making a top-seed
copy genuinely scarcer than a low float, which any number of copies can
share.

**Also critical: float and seed are rolled independently and neither
constrains the other.** A Pristine item can have a dull seed; a Scarred
one can be a legendary seed.

### Implementation in Vaultbreakers `[LOCKED]`

- Most cosmetics ship with **uniform finishes** where Pattern does nothing
- A handful ship as **Unstable Finishes** where Pattern dramatically changes
  the result

### Launch count: 2–3 Unstable Finishes `[LOCKED — D47 (Q16)]`
**Only 2–3 Unstable Finishes ship at launch**, not a broader set. This
maximizes focus — a legible, intensely-discussed meta around a small
number of finishes beats a diluted one where no single seed becomes
legendary. Of the ~1,000 seeds on each finish, maybe 8–15 [PH] produce
something spectacular.

**Say nothing about which finishes, or which seeds, are special.** Let
the community discover and name them.

**Why this is the best single idea in the design:** value hierarchy in CS
is community-generated, not developer-assigned — the tier lists reflect
what collectors catalogued over years, not official Valve data. In CS,
Seed #661
became the "Blue Gem" because players decided it did.

You ship 2–3 skins; the community generates thousands of conversations.
**Free, infinite, player-authored content.**

### Roblox feasibility `[UPDATED — prototype first, D63]`

**Decision (D63):** prototype the pre-baked seed-variant model in Studio
**before** locking it — how many discrete variants are achievable at
acceptable art cost decides whether Pattern feels like a ~1,000-value space
or a flat 5–10 option system.

Roblox has no custom shader support, so true CS2 texture placement is not
directly portable. Sharper than previously known: `SurfaceAppearance`
properties generally **cannot be modified by script at runtime at all**
— the one confirmed exception is `SurfaceAppearance.Color`, which can be
live-tinted (`09-research.md § No Custom Shaders`).

| Approach | Method | Risk |
|---|---|---|
| **Reliable** | Pattern drives **color tint** (confirmed runtime-doable) plus selection among a small set of **pre-baked texture variants** (UV/overlay differences baked in ahead of time, not manipulated live) | Low. Mobile-safe. Still produces distinct, catalogable variants. |
| **Ambitious** | Runtime image manipulation for genuine procedural patterns, via `EditableImage` or similar | **Unshipped/CPU-based as of 2026 — verify current API capability and mobile performance before committing.** |

Either way **the psychology transfers intact**, which is the part that
matters. The practical build is: bucket the 1,000 seed values into a
handful of discrete texture variants, apply live color tint on top for
finer-grained variation within each bucket.

---

# GEAR `[LOCKED]`

## Pickaxe tiers
`Wooden → Iron → Voltsteel → Riftedge`

Mines and fights (`02-core-loop.md § Combat`). Upgrade branches:
Extraction / Combat / Mobility.

## Gear score `[LOCKED — D92]`
**Formula:** `pickaxe tier index × 10, plus 1 point per purchased
pickaxe upgrade node across all three branches` (Extraction / Combat /
Mobility; Tech Path nodes don't count — D92), **plus the highest armor tier
owned × 10** (D112) [PH — coefficients to be tuned
against real Tech Path costs]. Used only for raid-matchmaking band
(R6, `07-decisions.md § D66`) and, by extension, Homestead sharding
(D79) — never for combat power itself, which stays server-authoritative
and separate (R5). A player never sees their own gear score directly;
it only ever manifests as which raid targets they're offered.

**Why this shape:** tier and upgrade count are the two things that
actually make a player "stronger" for raid purposes, and both are
already tracked server-side — no new state to add.

## Armor `[LOCKED — D112]`

The slice has armor pieces crafted from resources, one **chest** slot in the slice.
Each piece has a tier using the pickaxe's names (Wooden → Iron → Voltsteel →
Riftedge; only Wooden and Iron are reachable in the slice, since the top two
need Voltstone). A piece never upgrades — you craft a better one. Each tier
gives **knockback resistance plus a small damage reduction** [PH], kept small
so fights still resolve in 5–10 s (`02-core-loop.md § Combat feel`). The
**worn piece is never stealable** (R1); **spare pieces are stealable** in
raids like other loot (how many a raid takes is step-7 theft math, [PH]).
Armor pieces **don't trade** (same reason as D111); **armor skins trade** as
cosmetics. Gear score adds the highest armor tier **owned** × 10 [PH], so
taking armor off can't lower a raid band (R6).

## Pickaxes are not tradeable `[LOCKED — D111, supersedes D21]`

The pickaxe is a per-player tier, not an item: it can't be traded, sold or
stolen. Power stays earned. **Pickaxe skins** are the tradeable product —
they are cosmetics (§ Cosmetics), so earned skins trade freely (including
on the market), Robux-bought ones are swap-only (D65), and none are ever
stealable (R1). A crafter's product is now the look, not the tool.

## Loss rules
- **Gear is never stolen or traded** (R1, D111); see the Taxonomy table above
- Pickaxe **skins** roll Condition + Pattern for looks only (cosmetics;
  out of the vertical slice)

---

# COSMETICS `[LOCKED]`

**Never lootable under any circumstance. This line does not move.**

## Pattern (formerly "Seed") `[LOCKED — D93, resolves Q70]`
**Renamed from "Seed" to "Pattern."** The 1–1000 collector roll on gear
and cosmetics (`§ Roll 3` — link name unchanged, only the displayed term
changes) is now **Pattern #**, freeing "Seed" to mean crop seeds only
(`04-world-content.md § Seed sources`, D73). Every other doc reference
to the roll ("Seed," "Seed Showcase," "best-seed items") should read
"Pattern" going forward; the terminology carries through the rest of
this file as "Pattern."

## Rarity tiers `[LOCKED — D74; names and Mythic rule locked by D85]`

| Tier | Color |
|---|---|
| Common | Grey |
| Uncommon | Green |
| Rare | Blue |
| Epic | Purple |
| Legendary | Gold |
| **Mythic** | Red — **earned only; the Robux shop never sells Mythic** (D85) |

- Rarity is **independent of Condition and Pattern** — a Mythic can be
  Scarred with a dull Pattern.
- "Unstable" is a **finish property**, not a tier.
- Case odds per tier stay internal (D46).
- Rarity is the key for the Robux swap pool below and for any future
  trade-up mechanic.

## Trade-up contracts `[LOCKED — D97]`
Ten cosmetics of the same rarity tier can be consumed to produce **one
random cosmetic of the next tier up.** **Earned pool only** — Robux-pool
items can never enter a trade-up (D65's separation would otherwise leak
through the trade-up's random outcome). This is a genuine Credits-free
cosmetic sink: it removes ten items from circulation for one, so
retired case series (D31) get scarcer over time even without anyone
selling. Scope: v1.0.

## Provenance `[LOCKED — D104]`
Every drop, Case pull, and craft carries a lightweight provenance tag
showing **how and when** it was obtained — e.g. "Glutton drop, S1" or
"Riftfall Case, S2." **The original owner's name is opt-in only** and
off by default: showing a kid's name on an item that gets traded to a
stranger is a real social-safety risk this avoids by default, while
still letting players who want the flex turn it on.

## Two trading pools `[LOCKED — D65]`

| Pool | Source | Can trade for |
|---|---|---|
| **Earned** | Drops, Cases, crafting, Credits shop | Anything — Credits, items, market |
| **Robux** | Bought with Robux | **Only another Robux-pool cosmetic of the same rarity tier** |

Robux-pool cosmetics can **never** be sold for Credits, used to open or
buy Cases/Keys, or fed into any random-outcome mechanic. This is what
keeps Robux value out of the Credits economy entirely (R3, R7,
`09-research.md § Platform policy`).

| Type | Notes |
|---|---|
| Base skins | Visible from a distance — primary flex |
| Character skins | |
| Weapon skins | Where Unstable Finishes live |
| Auras | Rebirth-tier glow |
| Loot trails | Also functions as the Chase marker |
| Banners | Crew insignia |
| Lighting themes | Base ambience |
| Defense Plaque | Auto-tracks successful defenses |
| **Season badges** | Permanent proof of when you played — huge long-term flex |
| **Trophy Hall** | Walkable display of rare Grades and Patterns |
| **Pattern Showcase** | Best-Pattern items on pedestals (formerly "Seed Showcase," D93) |

---

# CASES `[LOCKED]`

**Sealed containers with random contents. Tradeable. Stealable while
sealed. Permanent — do not expire.**

## Why cases are lootable — the strongest mechanic in the item set

A sealed case is **Schrödinger's loot** — unknown value until opened.
It does three things nothing else does:

1. **Makes raiding thrilling.** Stealing resources is stealing a number.
   Stealing a sealed case is stealing a *possibility*. You run home not
   knowing if it's junk or a jackpot, and you open it in front of everyone.
2. **Creates a speculation market.** Unopened cases trade on expected
   value. Event cases appreciate. Players who don't want to gamble sell
   to players who do.
3. **Sharpens the bank/exposed decision.** Bank it sealed, or open it now
   and risk having something better to lose?

**Rule:** cases are stealable **only while sealed.** Once opened,
contents follow normal rules — cosmetics become untouchable forever.

## Permanent, not expiring `[LOCKED — D31 (Q25)]`
Cases **never expire.** They become genuine collectibles that appreciate
over time — the same dynamic that makes old CS cases valuable years
later. This trades away the forced-circulation benefit of an expiry
system in favor of long-term collector value.

## Tier is a total mystery before opening `[LOCKED — D32 (Q26)]`
**You cannot see a case's exact tier or contents before opening it —
same as Rust, where you never know exactly what a base holds before you
breach it.** Players read *inferred* value instead, off the same visual
signals that already drive raid targeting: base size and tier, the
gear worn by the base's owner, and defense investment. This keeps
raid-targeting a genuine scouting skill rather than a menu lookup, and
it means a case's real thrill is preserved for the opening moment, not
spoiled beforehand.

## Case sources

| Source | Case chance [PH] |
|---|---|
| NPC Trader (Exchange) | Purchasable, gameplay currency |
| Riftfall | ~15% (guaranteed in high zones) |
| Standard Cache | ~5% |
| Sealed Cache | ~40% |
| Rift Boss | Guaranteed high-tier |
| Raids | Whatever the victim had Exposed |

---

# KEYS `[LOCKED — Option A, tiered]`

**Keys cost gameplay currency only. Robux cannot buy keys, or any
currency that buys keys, at any remove.**

## Tiered keys `[LOCKED — D30 (Q24)]`
**Standard, Rift, and Event key tiers**, rather than one universal key.
This segments the market and allows price discrimination between case
grades — a Standard Cache doesn't compete on the same key market as a
Rift Boss drop. The tradeoff accepted is fragmented liquidity (three
markets instead of one), judged worthwhile for the added economic depth
and the ability to make Event keys a genuine limited-time good.

### Why not the CS model
CS's asymmetry — free cases, paid keys — is what gives cases market
value. But this is **literally the example in Roblox's own policy
documentation**, which covers indirect purchases and names spending Robux
on keys to open boxes specifically, requiring all outcomes and numerical
odds summing to exactly 100%. Roblox updated this in May 2026 to comply
with South Korean law and rolled it out globally.

### What Option A preserves
Everything economically interesting: case trading, key demand,
speculation, the save-up loop. **The exchange rate between cases and keys
becomes a real, player-discovered price** — now with three distinct
exchange rates instead of one, since keys are tiered.

### What it gives up
Only the monetization that would have drawn the loudest criticism.

(`08-questions.md § Q27` — reveal-delay animation still open.)

---

# COMPONENTS `[LOCKED]`

**No recipe. Loot only.** Rust model: springs, gears, and tech trash
cannot be crafted, which is why monument running matters.

| Component | Source |
|---|---|
| Rift Core | Rift bosses |
| Precision Gear | Sealed Caches, Glutton |
| Volt Cell | Riftfall, Reaches |
| Riftshard `[PROPOSED]` | Riftfall only |

### Riftshard `[PROPOSED]`
Riftfall-exclusive Component. No recipe, tradeable, stealable while
unbanked. **Job:** required input for Fabrication-branch cosmetic
recipes (`03-progression.md § Branches`). Gives Riftfall a signature
drop of its own, and means crafted cosmetics always trace back to a
contested world event — never purely to the market. Scope: v1.0
(Riftfall is not in the slice).

**Consequence:** a Prototype blueprint is **necessary but not
sufficient.** Elite crafting always requires world engagement and can
never be purchased purely off the market. Blueprint holders and component
farmers need each other.

---

# FRAGMENTS `[LOCKED, amended D22]`

| Fragment | Gates | Source | Tradeable |
|---|---|---|---|
| **Core Fragment** | Workshop II | Reach Warden, Glutton, Sealed Caches | **Yes** |
| **Rift Fragment** | Workshop III | Riftfall, Rift bosses | **Yes** |

**Cannot be bought from an NPC vendor, and never Robux-purchasable — but
tradeable between players** (`03-progression.md § Workshop`). This lets
non-combat players buy their way into Workshop progression, at the cost
of loosening the "everyone must personally touch world content" pressure
that untradeable Fragments would have enforced. Someone on the server
still has to loot the Fragment first; it just doesn't have to be the
person building the Workshop.

---

# BLUEPRINTS

Fully specified in `03-progression.md § Blueprints`. Summary for
taxonomy purposes:

- Common — auto-learned, not tradeable, **permanent once learned**
- Advanced — tradeable until learned, then bound, **wears out and must
  be relearned**
- Prototype — tradeable, **capped at 1 per player, never crew-shared**,
  **wears out and must be relearned**

Unlearned blueprints sit in Exposed storage and **are stealable.**
Learned ones are not. Advanced/Prototype blueprint drops are **visible on
the ground before pickup.**
