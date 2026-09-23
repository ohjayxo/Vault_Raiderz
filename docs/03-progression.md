# 03 — Progression

---

# THE WORKSHOP `[LOCKED]`

**Research is a place, not an inventory action.** This is the structural
insight borrowed from Rust: progression infrastructure is a physical,
tiered, raidable object inside your base.

## Tiers

| Tier | Cost | Unlocks |
|---|---|---|
| **Workshop I** | Resources only | Common blueprints, Tier 1 Tech Path, basic research |
| **Workshop II** | Resources + **5 Core Fragments** [PH] | Advanced research, Tier 2 Tech Path, Fabrication branch |
| **Workshop III** | Resources + **5 Rift Fragments** [PH] | Prototype research, Tier 3 Tech Path, elite crafting |

**Each tier must be placed adjacent to the previous one.** You cannot
discard lower tiers. (Rust model — WB2 requires WB1 nearby, WB3 requires
WB2.)

## Fragments are the gate `[LOCKED]`

**Fragments are tradeable** (`07-decisions.md § D22`) but never bought
from an NPC vendor, only sourced from: Reach Warden, Glutton, Sealed
Caches, Riftfall, Rift bosses — or purchased from another player who did.
**Also spent, in Rift-Fragment form, on Tier 3 Tech Path re-buys after a
tier reset** (`§ Tier 3 re-buy cost`, D76).

**Why tradeability was allowed:** it lets non-combat players (pure
Traders and Commerce-track Engineers) buy their way into progression
without ever fighting, which was flagged as a pacifist-viability gap.
The world-engagement pressure survives because *someone* on the server
still has to go loot the Fragment first — it just doesn't have to be you.

## Workshops as raid targets `[LOCKED — D23]`

In Rust, workbenches have low HP (500/750) and any raider reaching the
workbench room destroys them in seconds — a prime raid target.

Vault Raiderz softens this per R2 for most tiers, with the elite-tier
exception now locked in:

| Vault Tier | Raider effect on Workshop |
|---|---|
| 1–4 | Untouchable |
| 5–7 | Knocked offline 15 min [PH], free repair |
| 8–10 | **Permanently destroyed** if targeted (`01-pillars.md § R2`, `07-decisions.md § D23`) |

A destroyed Workshop must be rebuilt from Tier I, including re-farming
its Fragment gates — this is the single harshest consequence in the
entire raid system, reserved for the top band only.

## Public Workshop I `[LOCKED]`
A free Workshop I exists at **The Exchange** in the safe zone. Nobody is
ever hard-blocked from research. (Mirrors Rust's free public research
table at Outpost, which is how most solos bank their first blueprint.)

## Workshop access as a service `[LOCKED — D24]`

**Players with a Workshop III can grant timed crafting access to
visitors — manually only, not automated.**

This is directly modeled on real Rust behavior — players trade workbench
access for materials. It is the single best social mechanic in the
design:

- Creates a **service economy** — renting infrastructure, not selling goods
- **Gives players a reason to visit a base peacefully**
- Reputation value: "runs a public Workshop III" becomes an identity
- A safe, non-combat income path
- **Built-in risk:** granting access means letting someone into your base.
  Trust becomes a mechanic; betrayal becomes a story.

**Why manual, not automated:** an automated rental listing turns the
Workshop into a passive vending machine and removes the trust
interaction that makes it interesting. Manual granting keeps it social —
you have to actually let someone in.

## Cross-shard workshop directory `[LOCKED — D62]`
Because the Homestead is sharded (`02-core-loop.md § Server sharding`),
a lightweight **"workshops open" directory** lists Workshop III owners
offering access across shards, built at launch rather than deferred.
Granting access stays manual (D24) — the directory only helps visitors
find an owner; it never grants anything automatically. Scope: v1.0
(Workshop III is not in the slice).

---

# THE TECH PATH `[LOCKED]`

**The tech tree replaces the class/specialization system entirely.**

Earlier drafts had players picking Prospector/Engineer/Raider/Trader from
a menu. That is cut (`07-decisions.md § D11`). Instead:

> **Your tech path is your class.**

### Why this is better
- **Emergent, not declared** — you become something through ~40 spending decisions
- **Gradual** — nobody is locked in at minute 10
- **Readable** — others infer your build from gear and behavior (armor and behaviour; pickaxe tier is hidden under skins)

### The mechanism that makes it work
**You cannot afford the whole tree.** In Rust, clearing everything costs
roughly 10,820 scrap across 285 items, and almost nobody clears a full
tier — players beeline the handful of nodes they need. **The scarcity is
the class system.**

## Structure `[LOCKED — D108]`

- **Three separate trees, one per Workshop tier.** Workshop II is not
  just better crafting — it opens an entirely new tree.
- **Prerequisite chains.** A node unlocks only after the ones before it
  on its path. Reaching a deep item means buying everything leading to it.
- **Cost scales with value** — ~25 scrap [PH] entry nodes up to several
  hundred for tier-defining items.
- **Mobile-first UI `[LOCKED — D60]`:** one vertical, collapsible tree
  per Workshop tier with large tap targets — no pan/zoom, no separate
  list mode. Detailed layout is a build-phase UI spec item.

### Tier budgets [PH]

| Tier | Full clear | Realistic seasonal clear |
|---|---|---|
| Tier 1 | ~1,200 scrap | 20–30% per season, **accumulating** — Tier 1 never resets (D72) |
| Tier 2 | ~4,000 scrap | 20–30% |
| Tier 3 | ~6,000 scrap | 20–30% |

**That gap is the entire design.**

**Consequence of a permanent Tier 1 (D72):** a long-tenured player will
eventually own most or all of Tier 1, so Tier 1 stops expressing class
over time. Class identity for veterans lives in Tier 2/3, which still
reset. Tier 1 is deliberately the "earned forever" layer, not the class
layer.

**Visibility `[LOCKED — D108, resolves Q48]`:** the full tree for each
unlocked Workshop tier is visible before nodes are affordable, so players
can plan a path.

## Branches `[LOCKED — D108]`

| Branch | Buys | Identity |
|---|---|---|
| **Extraction** | Mining speed, Grade odds, node scanners, drill rigs, auto-harvesters | Miners |
| **Defense** | Wall plating, traps, shock fences, decoy vaults, alarm networks | Homebodies |
| **Breaching** | Breach charges, better lockpick tools and gadgets (basic ones are Workshop I crafts for everyone), carry-speed gear | Raiders |
| **Commerce** | Lower fees, bulk listing, price history depth, market alerts, storage | Traders |
| **Fabrication** (T2+) | Case crafting, cosmetic recipes, component synthesis | Crafters |

**Fabrication only appears at Workshop II** — the crafter identity is
something you grow into, giving mid-game players a new direction exactly
when the early loop is going stale.

### Example: Tier 1 tree shape [PH]

```
                    Workshop I
                   (opens tier 1)
                         |
      +----------+-------+-------+----------+
      |          |               |          |
  Extraction  Defense       Breaching   Commerce
   25 scrap   25 scrap       25 scrap   25 scrap
      |          |               |          |
 Node scanner  Wall plating   Charge I   Bulk listing
   60 scrap    60 scrap       80 scrap    60 scrap
      |          |               |          |
  Drill rig   Shock fence   Smoke bomb  Price history
  150 scrap   150 scrap     140 scrap    180 scrap
```

## Tech Path respec `[LOCKED — D37]`
Respeccing grants a **partial Scrap refund of 50%** [PH — starting value,
D109]. Full
refund would make every choice reversible and cheapen the scarcity that
makes the tree function as a class system; zero refund was judged too
harsh for a young audience experimenting with builds.

## Staggered tier reset `[LOCKED — D72, supersedes D19]`
**The Tech Path resets by Workshop tier, on different clocks:**

| Tier | Resets | Cadence [PH] |
|---|---|---|
| **Tier 1** | **Never** | Permanent |
| **Tier 2** | Every season boundary | 6 weeks |
| **Tier 3** | Mid-season and season boundary | 3 weeks |

The same schedule applies to **learned blueprints of the matching tier**
(Common ↔ T1, Advanced ↔ T2, Prototype ↔ T3), however they were
learned (`§ Research Bench`, `§ Blueprints`). **Workshop structures
themselves never reset** — only unlocks do (R2).

Higher tiers churn faster on purpose — the same inversion as D33's
blueprint wear-out: the deepest content stays contested, while the early
game stays permanent and friendly.

## Tier 3 re-buy cost `[LOCKED — D76]`
After each Tier 3 reset, re-buying a Tier 3 node costs a **Rift
Fragment** as well as Scrap. Without this, veterans holding Scrap at the
week-3 reset (Scrap only converts at the season boundary — § Seasons)
instantly rebuy their tree and the reset means nothing.

## Node visibility `[LOCKED — D36]`
Other players' unlocked Tech Path nodes are **visible to crewmates only**,
not server-wide. Crews can coordinate splits internally; your build stays
private leverage against everyone outside your crew.

---

# CREWS `[LOCKED]`

Crews are 2–4 players (`01-pillars.md`). Three mechanics bind them
together beyond shared raiding:

## Zero-chat crew invites `[LOCKED — D61]`
Crew formation works entirely through **invite/accept UI** — no chat is
ever required to form, join, or leave a crew, matching the zero-chat
market rule (`06-economy.md § Zero-chat trade`).

## Crew-shared Tech Path nodes `[LOCKED — D25]`

**If one crew member unlocks a node, every current crew member can craft
from it at their own Workshop.** This is a genuine capability unlock, not
a bonus multiplier — a 4-person crew can cover in one season what would
take a solo player four seasons (`§ Crews split the tree` below).

**Anti-exploit rule — the join/leave lockout:** Rust crews are documented
abusing team-sharing by joining a team purely to inherit its unlocked
blueprints, then leaving. To block the equivalent here:

- Shared node access requires **minimum crew tenure of 24 hours** [PH —
  starting value, D109] before a new member gains it.
- **Leaving a crew immediately revokes** all shared-node access. You keep
  only what you personally unlocked.
- This applies to Tech Path nodes only. **Prototype Blueprints are never
  crew-shared** (`§ Prototypes and Rift bosses` below) — each player must
  learn their own copy regardless of crew membership.

## Crew Vault `[LOCKED — D49; permissions set by D90, disband rule by D91]`

Crews get a **shared Crew Vault**, separate from individual player
vaults.

**Permissions (D90):** the crew **leader has full access** — deposit,
withdraw, invite, disband. **Members deposit freely but withdraw only up
to a daily cap** [PH]. This keeps the Vault genuinely shared without
letting any one member empty it unilaterally, without needing a second
role tier for a 2–4 person crew.

**Disband rule (D91):** each member **reclaims exactly what they
personally deposited** (tracked per-member, R5). Any remainder — raid
loot dropped in by the group rather than an individual, interest, etc. —
**splits equally** among members at disband. Nothing is forfeited; this
keeps R2's "nothing lost" spirit intact for crew play too.

A shared Crew Vault is also a **strong raid target**: it concentrates
value the way an individual vault does, but a successful raid on it hits
an entire crew's morale at once, which is a much bigger emergent moment
than any single-player raid.

## Crew raid loot split `[LOCKED — D50]`

**Contribution-weighted by default**, with an option for any member to
**gift their share to a specific crewmate** instead of taking it. This
avoids both failure modes: pure equal-split under-rewards the player who
did the actual lockpicking or tanking, and pure leader-allocation creates
resentment. The gift option lets a crew self-organize around whoever
needs the item most (a Trader gifting resources to the Engineer who needs
them for a build, say) without forcing a rigid rule to cover every case.

## Crews split the tree `[LOCKED — D108]`

A documented Rust mistake is whole teams rushing the same tree instead of
splitting trees and sharing crafted output. With the D25 sharing rule in
place, four people cover in one season what would take one player four
seasons.

---

# RESEARCH BENCH `[LOCKED]`

The second unlock path. Both exist because they solve different problems.

**Consume a looted item + Research Scrap → learn its blueprint.** Learned
blueprints follow the tier reset schedule (`§ Staggered tier reset`, D72)
— Common-tier knowledge is permanent; higher tiers are not.

**Confirmed: the Bench consumes the physical item** (`07-decisions.md §
D51`). Prototype blueprints researched at the Bench follow the same
D77 exemption — the 3-week reset is their only churn, not D33 wear-out. The sacrifice is the point — a looted item in your hands is one
item; a researched item is every one you'll ever have materials for. No
softened partial-materials-back version; the tension of the trade-off is
worth more than protecting a player from an avoidable mistake.

### The decision logic (mirrors Rust's)
- **Looted the item?** Research it — cheaper, but it consumes the item
- **Need something that hasn't dropped?** Tech Path — expensive, but certain

This means looting and grinding feed the same progression from two
directions.

## Experiment `[PROPOSED]`
Spend scrap at a Workshop for a **random unlock from that tier**.
Rust prices this roughly 75/300/1000 scrap by tier. Good late-season
scrap sink once you've bought everything you actually wanted. Gameplay
currency only, so it stays clear of R7.

---

# BLUEPRINTS `[LOCKED]`

Blueprints make **knowledge** a scarce, tradeable resource — separate
from materials and separate from skill. Without them, everyone eventually
knows every recipe and specialization decays.

## Tiers

| Tier | Source | Tradeable | Durability |
|---|---|---|---|
| **Common** | Progression, quests, early caches | No | **Permanent once learned** (never resets — D72) |
| **Advanced** | Caches, Riftfall, NPC trader | Until learned | **Wears out — must be relearned**; also resets every 6 weeks (D72) |
| **Prototype** | Rift bosses, Static Secrets, seasonal | Yes, but 1-per-player | **Resets every 3 weeks** (D72) — its only churn; D33 wear-out does not apply (D77) |

## Tiered durability `[LOCKED — D33]`

**Low-tier (Common) blueprints stay permanent once learned — friendly
and low-stakes for new players.** **Advanced blueprints wear out with
repeated use and must be relearned; Prototype is exempt (D77), its 3-week
reset is its only churn.** This is a deliberate inversion of the naive assumption that
rarer should mean more durable: the goal is ongoing demand exactly where
the economy is deepest. A veteran Engineer with a worn Advanced
blueprint has to go back out and re-earn it — keeping boss-farming crews
relevant permanently instead of being a one-time unlock that's solved
forever.

## Bound-on-learn `[LOCKED]`

A blueprint is a tradeable object **right up until you use it.**

- Supply stays finite — blueprints permanently leave circulation when consumed
- Creates real tension: learn it, or sell it to someone who wants it more?
- Protects crafter identity — a rare recipe is a durable advantage
- Natural sink that doesn't feel punishing

## Learning announces publicly `[LOCKED — D35, narrowed by D78]`

**Learning a Prototype blueprint triggers a public announcement**,
similar in spirit to the Vaultborn Grade announcement. **Advanced no
longer announces (D78)** — with Tier 2/Advanced resetting every 6 weeks (D72),
announcing every Advanced relearn would have flooded the broadcast queue
(D58) with noise. This builds strong social proof — "the guy who just
learned Riftedge Housing" is an identity — at the cost of painting a
target on producers of valuable goods. That trade-off is accepted
deliberately: it's the same logic that makes flex visible elsewhere in
the design (`01-pillars.md § Design rubric`, criterion 7).

## Prototypes and Rift bosses `[LOCKED]`

Rift bosses drop **Prototype Blueprints** — recipes obtainable no other
way:
- **Unstable Finish cosmetics** (the Pattern-sensitive ones — the entire
  collector meta traces back to boss kills)
- Top-tier pickaxe components
- Elite defense modules
- Craft-only case types

**Not server-unique, but capped at one copy per player** (`07-decisions.md
§ D34`). Many players across the server can independently learn the same
Prototype — this isn't an exclusive monopoly system — but **a single
player can only ever hold/learn one copy**, and **Prototype blueprints
are never crew-shared** even though Tech Path nodes are. This keeps
elite recipes genuinely earned per-person while avoiding the harsher
server-monopoly model that would let one crew corner an entire recipe.

**Economic consequence:** a server's supply of the most desirable
cosmetics depends on how many players have beaten Rift bosses and chosen
to *learn* rather than *sell* those recipes. Boss-farming crews become
the server's manufacturers — a real power structure emerging from
gameplay, not from a leaderboard.

## Blueprint drops are visible before pickup `[LOCKED — D52]`

Seeing **"Prototype Blueprint"** labeled on the ground during a contested
Riftfall or boss fight turns it into the thing everyone fights over,
rather than a surprise discovered after the fact. This applies to
Advanced-tier and above; Common blueprints are unremarkable enough that
visibility wouldn't change behavior.

## Blueprint ≠ ability to craft `[LOCKED]`

Certain **Components** have no recipe at all — loot only. (Rust model:
springs, gears, and tech trash cannot be crafted, which is why monument
running matters.)

So a Prototype blueprint is **necessary but not sufficient**. See
`05-items.md § Components`.

## Blueprint Mastery `[PROPOSED]`

Repeated crafting from a blueprint builds Mastery with that recipe:

| Uses [PH] | Unlock |
|---|---|
| 1–9 | Base craft |
| 10 | Material cost −10% |
| 25 | Improved Condition roll chance |
| 50 | Small chance of bonus output |
| 100 | **Signature** — crafted items carry your name |

**Signature is the sleeper feature.** A maker's mark means a known
crafter's output carries a reputation premium — player-authored value,
the same dynamic that makes CS seeds interesting. Someone becomes "the
guy who makes the good Riftedge skins," and that identity is worth more
than the items.

Mastery is **non-transferable**, so a rich player cannot buy their way
into being a great crafter.

**Open question:** how Mastery interacts with the D33 wear-out rule for
**Advanced** blueprints (D33 no longer applies to Prototype — D77) —
does relearning a worn-out Advanced blueprint preserve accumulated
Mastery, or reset it? Flag for a future pass.

---

# REBIRTH `[LOCKED — amended D70; deferred to S2+ by D86]`

**Scope: S2+, not in the slice, not in v1.0 (D86).** Prestige-only
rewards mean rebirth now resets progress for looks alone — worth
revisiting once the base game has enough cosmetic depth to make that
trade appealing.

**Hybrid model, prestige-only rewards.**

| Resets | Persists |
|---|---|
| Resources | **All cosmetics** |
| Vault tier | Trophies |
| — | Titles |
| — | Season badges |
| — | Rank history |

Same principle as R1: lose the fungible, keep the identity.

**Rewards are prestige only (D70):** a visible rebirth tier marker,
rebirth-exclusive cosmetics, and titles. **No stat or income
multipliers** — multipliers were power, and paired with the vault-tier
reset they let veterans drop into the beginner raid band. There is **no
Robux rebirth skip.** Rebirth also never lowers your raid band: lifetime
peak vault tier counts (D66).

**Open:** with multipliers gone, the rebirth reward has to be
compelling on looks alone — the reason it's deferred (D86) rather than
cut outright (`08-questions.md § Unresolved secondary detail`).

---

# RANKED LADDER & SEASONS `[PROPOSED]`

## Vault Rank
`Scrap → Iron → Voltsteel → Obsidian → Vaultborn (top 500 globally)`

**Points from:** successful raids, successful defenses, market volume,
rare Grade discoveries, event wins.

**Weighted so all three pillars can climb.** Hybrid play is more
efficient, never required (`01-pillars.md`).

## Reputation tracks `[LOCKED — D81, replaces "Mastery tracks"]`
Three independent XP tracks formalizing the three pillars — **Miner,
Trader, Raider Reputation** — earned by doing that pillar's actions
(server-validated, R5).

**Rewards are titles and cosmetics only, never stats.** The old
"Mastery tracks" granted mining speed, fee reduction, and combat perks,
which duplicated the Tech Path branches and edged into R3/R8. Renamed
from "Mastery" to end the collision with Blueprint Mastery.

A pure-track player can reach Vaultborn. A hybrid gets there faster
(D8 unchanged).

## Level `[LOCKED — D82]`
One visible, **permanent** number — the sum of the three Reputation
tracks. **Never resets** (not at season, not at rebirth). Jobs:

1. The persistent "earned" spine that survives every reset in the game
2. The R4 reveal gate — systems unlock at Levels, including trading at
   **Level 10 [PH]** (`06-economy.md § Access gating`)
3. Rewards titles, cosmetics, and slots — never stats

**Level curve `[PH — placeholder, v5.7 build round; D80 note]`:** each Reputation track turns
XP into a track level, where the XP to **reach** track level *n* is
`floor(100 × n^1.5)` (levels 1 / 2 / 3 / 5 / 10 / 20 need 100 / 282 / 519 /
1,118 / 3,162 / 8,944 XP). **Level = the sum of the three track
levels**; everyone starts at Level 0. Because each level costs more than the
last, spreading XP across tracks is faster — Level 10 from one track takes
3,162 XP, split 4/3/3 takes 1,838 — which is the "hybrid gets there faster"
rule above. For Level 10 in ~2–3 sessions (`06-economy.md § Access gating`,
~90–135 min), XP grants should total roughly **15–30 XP per minute of active
play**. Level is derived from XP, never stored separately (D80 note).

**Each season ships a free season track, plus a premium track (D83)** —
both hold only account-bound, non-random cosmetics (R3, R7). Premium is
purely a faster/richer cosmetic path, never a different reward category.

## Seasons — 6 weeks [PH]

`[LOCKED — D48, amended by D68 and D72]`

| Resets | Persists | Converts |
|---|---|---|
| Rank | Resources | **Research Scrap → cosmetic-only currency** (D68) |
| **Tech Path Tier 2 and Tier 3** (D72) | **Tech Path Tier 1** (D72) | |
| **Learned Advanced/Prototype blueprints** (D72) | Learned Common blueprints | |
| — | Credits | |
| — | The global market | |
| — | Plots | |
| — | Cosmetics | |
| — | Season badges | |
| — | Rank history | |
| — | Level (D82) | |

Tier 3 also resets at mid-season (week 3 [PH]) with **no** Scrap
conversion — see `§ Tier 3 re-buy cost` (D76) for the Rift Fragment re-buy
that keeps that reset meaningful.

**Why the split:** the Tech Path is treated as its own progression system
distinct from "the economy." Wiping it every 6 weeks means nobody
compounds tree advantage forever and there's a genuine land-rush at
season start, while resources/Credits/market persisting means players
don't lose their accumulated wealth or base investment on a clock.
**Scrap converts rather than persists (D68)** — otherwise veterans enter
every season with a Scrap stockpile and instantly rebuy their tree,
making the reset fictional. The D48 reconciliation is now confirmed and
refined by D68 and D72.

Each season ships: a themed cosmetic line, **a new Unstable Finish**
(feeding the Pattern meta), a rotating world event, an exclusive rank
reward, and a swapped Rift boss with a fresh Prototype table.

### Why seasons earn their place
1. Content cadence reusing existing systems — no new mechanics required
2. Prevents permanent ladder ossification by whales
3. Natural re-engagement spike every six weeks for lapsed players
4. The Tier 2/3 resets prevent veteran players from permanently
   out-classing new arrivals in build depth, while Tier 1 stays
   permanent so early progress always feels earned

**Weekly leaderboards reset separately** (Richest, Best Raider, Best
Defender, Most Rifts). Permanent boards mean one whale owns #1 forever
and everyone else disengages.
