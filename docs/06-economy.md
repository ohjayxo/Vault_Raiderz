# 06 — Economy

Item definitions live in `05-items.md`. This file covers how value moves.

---

# CURRENCIES `[LOCKED]`

**Four separate currencies with strictly separate jobs** (the cosmetic currency added by D68). The separation
is the point — it prevents any one activity from buying everything.

| Currency | Earned from | Spends on | Buyable with Robux? |
|---|---|---|---|
| **Credits** | Selling goods, market sales, mob drops | Market purchases, vendor goods, Keys, Cases | **No** |
| **Research Scrap** | Recycling, dismantling duplicates, mob drops (**not NPC sales — D69**) | Tech Path nodes, Research Bench, Experiment | **No** |
| **Marks** (D84) | **Converted from Research Scrap at each season boundary** (D68), rate [PH] | Seasonal cosmetic shop only; Marks and Marks-bought items are **account-bound** (D84) | **No** |
| **Robux** | Real money | Cosmetics, bank capacity, convenience, slots | — |

## Why Scrap is separate from Credits `[LOCKED]`
A rich trader must not be able to buy their way up the Tech Path. They
have to recycle, loot, and grind like everyone else. Progression is
earned; goods are traded.

## Why nothing gameplay-facing is Robux-purchasable `[LOCKED]`
R3 and R7 (`01-pillars.md`). Also keeps the entire Case/Key loop outside
Roblox's Paid Random Items policy — see § Monetization below.

## No indirect Credits → Scrap route `[LOCKED — D69]`
NPC sales no longer yield Scrap, and **items acquired through the market
recycle at a heavy loss** [PH]. Each item carries a server-side
"market-acquired" flag (R5). Without this, a rich trader could buy goods
with Credits and recycle them into Tech Path progress.

---

# THE EXCHANGE (global market) `[LOCKED]`

## Two tiers of selling

| Tier | When | Mechanism |
|---|---|---|
| **NPC buyer** | Immediately, from minute one | Zero friction, always available; price **diminishes per item sold that day, resets daily** (D94) |
| **The Exchange** | Unlocks at Level 10 (D82) | List at your own price, server-wide, **with price history graph** |

## NPC price decay `[LOCKED — D94]`
The formerly flat NPC buy price was an **unlimited Credits faucet** —
sell endlessly at a fixed rate with no cost. Now the price per unit
**diminishes with each sale to that NPC within a day**, resetting at
day boundary. This keeps the NPC as the always-available zero-friction
option for new players, while removing it as an infinite-Credits
exploit for anyone with a large stockpile.

## The differentiator `[LOCKED]`

**Price history displayed in-game.** This remains a genuine gap in the
market — every major Roblox trading game forces players out to a wiki or
Discord to learn values. Putting price discovery *inside* the game is a
real, defensible advantage.

## Technical feasibility `[CONFIRMED]`

Roblox's own documentation lists **cross-server trading and auctioning**
as a primary MemoryStoreService use case — universal trading between
servers where users bid on items with real-time changing prices via a
sorted map — and explicitly notes memory stores support permanent
features like a global marketplace, where the marketplace persists but
listings expire.

### The hard architectural constraint `[LOCKED]`

**MessagingService is best-effort.** Roughly 150 messages/minute per
server and 60/minute per topic at 1KB payloads, with no delivery
guarantee — and the most common cross-server bug is studios broadcasting
economy events over it and assuming delivery.

**Therefore:**
- **MemoryStore is the authority. MessagingService is only a hint that
  something changed.**
- Servers reconcile against the store on a 30–60 second interval
- **Every economy action validates against MemoryStore. No exceptions.**

### Broadcast priority queue `[LOCKED — D58]`
All server-wide announcements (Vaultborn finds, blueprint learning,
bosses, Blackout, Chase markers, raid alerts) go through **one
rate-limited, prioritized event queue**. Raid-owner alerts and Chase
pings rank highest; cosmetic flex announcements rank lowest and are the
ones dropped on overflow — never a raid alert.

Getting this wrong produces duplication exploits that will gut the game.

## Access gating `[LOCKED]`
Market access is **progress-gated**, not time-gated. Ties to the tiered
system rather than an arbitrary clock. Serves as the primary
scam/bot/alt-account defense.

**Gate `[LOCKED — D82]`:** direct trading and the Exchange both unlock
at **Level 10** [PH] (~2–3 sessions of active play —
`03-progression.md § Level`). Level only comes from
server-validated actions, so bots and alts must put in real play first.
The first Robux prompt fires at this same moment (locked).

## Zero-chat trade `[LOCKED — D61]`
Listings are **fixed-price only — no haggling UI, for anyone.** Experience
chat is off by default under age 9 for a real share of the audience
(`09-research.md § Chat & Social Age-Gating`), so the market is built to
work identically whether or not a player can talk, rather than layering
an optional negotiation feature on top. See `03-progression.md § Crews`
for the matching rule on crew invites.

## Robux-pool swaps `[LOCKED — D89]`
Robux-pool cosmetic swaps (`05-items.md § Two trading pools`, D65) happen
in the **direct trade window only**, not the fixed-price Exchange
listings above — a swap is item-for-item, not a priced listing. The
direct trade window visibly separates the two pools (Robux-pool items
can only be dragged against other Robux-pool items of the same tier) so
a player can never accidentally attempt a cross-pool trade.

## Trade holds `[LOCKED — D98]`
A newly acquired item **above a value threshold** [PH] carries a short
trade hold — a few hours at most — before it can be re-traded. Below
that threshold, items trade immediately. This targets rapid high-value
flipping (rubric #11, exploit resistance) without slowing down ordinary
low-stakes trading, which stays instant.

## Bounties `[LOCKED — D96]`
A player can post a **Credits bounty on a raider who hit them**, visible
only to players in that raider's matchmaking band (R6/D66) — this keeps
a bounty from turning into a server-wide dogpile on one player. Bounties
are **capped** [PH], **expire in 24 hours**, only **one active bounty
per target** at a time, and the **poster stays anonymous**. A portion of
the bounty is taxed on posting, same as a market sale. Scope: v1.0.

---

# SINKS AND FAUCETS

An economy with faucets and no sinks inflates until nothing has value.

## Faucets (currency/goods entering)

| Faucet | Notes |
|---|---|
| Resource nodes | Primary, scaled by Grade |
| Offline production | Mandatory pull-back hook |
| Mob and boss drops | PvP-free income floor |
| World Caches, Riftfall | Event-driven bursts |
| Crops | Safe income path |
| Recycling → Scrap | Converts junk to progression; market-acquired items at heavy loss (D69) |

## Sinks (value leaving permanently)

| Sink | Mechanism | Importance |
|---|---|---|
| **Raid destruction** | ~20% [PH] of stolen goods destroyed in transit | **Critical.** Without it raiding merely circulates wealth. |
| **Market tax** | 5% [PH] on every sale | Primary Credits sink; also makes wash trading lossy |
| **Breach Charges** | Consumed per raid | Self-balances raid frequency (Rust model) |
| **Keys** | Consumed per Case opened | Scales with how many Cases exist |
| **Tech Path** | Scrap spent permanently | Main Scrap sink |
| **Season conversion** | Scrap → cosmetic currency at each season boundary (D68) | Clears the Scrap stockpile every season |
| **Rare-seed vendor** | 5-min rotating Credits stock (D95) | Credits sink replacing the one D73 removed |
| **Trade-up contracts** | 10 same-tier cosmetics → 1 higher-tier (D97) | Cosmetic-supply sink; drives Exchange activity |
| **Bounties** | Credits posted on a target, capped, taxed (D96) | Credits sink; social/creator content |
| **Research Bench** | Consumes the item *and* scrap | Double sink |
| **Experiment** | Random-unlock gamble | Late-season scrap dump |
| **Defense charges** | Deplete when triggered, refilled with resources | Reason to log in |
| **Blueprints** | Leave circulation permanently when learned | Keeps supply finite |
| **Consumables** | Gadgets; teas in S2 (perishable) | Ongoing demand |

---

# INTERDEPENDENCE — why the market is real `[LOCKED]`

The market only matters if players genuinely **cannot** supply
themselves. Five mechanisms enforce that:

1. **Tech Path scarcity.** You cannot afford the whole tree. If I went
   deep Extraction and you went deep Fabrication, I *literally cannot*
   make what you make — not "slower," cannot. Crews soften this only
   *within* the crew, via crew-shared nodes (`03-progression.md § Crews`)
   — the interdependence between separate crews and solo players stays
   fully intact.
2. **Blueprint tiered durability.** Common blueprints are permanent, but
   Advanced and Prototype blueprints **wear out and must be relearned**
   (`03-progression.md § D33`) — so even a blueprint holder needs
   continued access to the item or the world content behind it, not just
   a one-time unlock.
3. **Components are loot-only.** No recipe exists. Blueprint holders need
   component farmers.
4. **Riftsalt is contested-zone-only, though now tradeable (D20).**
   Someone still has to personally farm it in danger; a safe player can
   only ever buy it from someone who did, never manufacture it
   themselves.
5. **Prototype blueprints cap at 1 per player, never crew-shared (D34).**
   Even inside a crew that shares Tech Path nodes, elite recipes stay
   individually earned.

**Fragments are now tradeable (D22)**, which loosens pure
self-sufficiency further than earlier drafts intended — a rich Trader can
buy their way into faster Workshop tiers without personally grinding for
them. (Gear itself does not trade — D111; pickaxe skins do, as cosmetics.) This is an accepted tradeoff: it deepens
the market and strengthens the pacifist-viability path, at the cost of
some of the "you must touch world content yourself" pressure. The
remaining four mechanisms above still keep genuine scarcity in the
system.

## The Case/Key triangle `[LOCKED, amended D30]`

- **Credits** → buy Cases and **tiered Keys** (Standard / Rift / Event —
  `05-items.md § Keys`)
- **Keys** → sunk permanently on every open; demand scales with Case
  supply **within each tier separately**, since the three key markets
  don't share liquidity
- **Cases** → created by world activity, **never expire (D31)**, destroyed
  only by opening; value floats against Key price and current cosmetic
  desirability, with room to appreciate indefinitely as genuine
  collectibles

**Players who love gambling buy Cases and Keys. Players who hate
gambling farm Cases and sell them.** Both are profitable playstyles and
they need each other — real interdependence, not manufactured.

A trader who notices Key prices spiking after a Riftfall flooded the
server with Cases can genuinely profit. That depth exists nowhere else on
the platform.

---

# CREW VAULT `[LOCKED — D49]`

Crews (2–4 players) get a shared **Crew Vault**, separate from individual
player vaults, fully specified in `03-progression.md § Crews`. It
participates in the economy the same way a personal vault does — it can
be raided, it has a bank/exposed split — but uses the permission
and disband rules defined there (D90, D91) so a shared pool can't be
unilaterally emptied by one member.

---

# TRADE SAFETY `[LOCKED]`

**Trade scamming is the #1 community-destroying problem in Roblox trading
games. Do not ship without these.**

| Safeguard | Purpose |
|---|---|
| Confirmation screen showing exactly what each side gives and receives | Baseline clarity |
| **5-second lock before Confirm becomes clickable** | Kills last-second swaps |
| Trade history log | Dispute resolution |
| Warning flag when an item is listed far below market average | Protects the uninformed |
| Progress-gated trading access | Bot and alt-account defense |

---

# MARKET MANIPULATION `[OPEN — known gap]`

A global market with real prices invites wash trading, price fixing, and
alt-farming. **No system currently fully addresses this.**

Minimum viable defenses `[PROPOSED]`:
- Per-account daily trade volume caps
- Anomaly detection on repeated same-pair trades
- Progress-gated market access (already locked)
- Market tax high enough to make wash trading lossy

This remains an unsolved risk. See `10-roadmap.md § Known risks`.

---

# MONETIZATION `[LOCKED]`

## Direct Robux purchases — no randomness

| Item | Type |
|---|---|
| Cosmetic skins (base, character, weapon, aura, trail) | Primary revenue |
| Bank capacity expansion | Convenience |
| Harvester Drone gamepass | Convenience |
| Extra defense slot | Convenience |
| Fast travel unlock | Convenience |
| VIP private server | Convenience |

**Most revenue should come from cosmetics**, which is why the Pattern
system matters commercially as well as socially.

**Robux cosmetics stay in their own pool (D65):** tradeable only for
another Robux-pool cosmetic of the same rarity tier — never for Credits
(`05-items.md § Two trading pools`). The Robux rebirth skip token is
**cut** (D70) — rebirth now grants prestige only, but skipping to it was
still buying progress.

## Name Tags `[LOCKED — D99]`
A Credits-purchasable cosmetic that displays a short tag under a
player's name. Built from a **preset word bank only — no free text
entry.** Chat is off by default under age 9 (`09-research.md § Chat &
Social Age-Gating`); a free-text field carries the same moderation risk
chat does, so Name Tags sidestep it entirely rather than adding a filter
that will eventually miss something. Scope: v1.0.

## Never sold `[LOCKED]`
Raid immunity · protection beyond the bank · combat advantage · admin
powers · Research Scrap · Fragments · Credits · Keys · anything gating
progression.

## The automation fairness line `[LOCKED]`
Automation is always **slower per minute** than active play at equal
investment. A paying AFK player must lose to a grinding free player.

This is precisely the line Steal a Brainrot is criticized for crossing —
Polygon noted that the best items are only available for cash, including
purchasable server-administrator abilities. That criticism is the
differentiator.

## Platform policy constraint `[LOCKED]`

Roblox's Paid Random Items policy requires that for items purchased with
Robux — **or indirectly via in-game currencies purchased with Robux** —
all possible outcomes and actual numerical odds must be displayed, summing
to exactly 100%. It names keys-for-boxes as an explicit example. The
policy was updated in May 2026 to comply with South Korean game law and
rolled out globally; developers on the forums expect enforcement to hit
simulator games hard.

**Vault Raiderz sidesteps the category entirely** by keeping Credits
non-purchasable **and** by keeping Robux-bought cosmetics in a separate
swap-only pool, so no Robux-bought good can ever be converted into
Credits, Keys, or Cases (D65). Verify current policy before any change
to this.

## First Robux prompt `[LOCKED]`
**At global trading unlock.** Not earlier. The timing of the first upsell
shapes conversion more than the price does — too early reads as greedy.
