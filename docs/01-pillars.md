# 01 — Pillars & Design Rules

---

## The pitch `[LOCKED]`

**Vault Raiderz**
> "Mine it. Bank it. Or lose it."

Three words carrying the entire tension: production, protection, loss.

The title and thumbnail sell **theft**. The design underneath is a
**production economy**. That gap is intentional — theft is the most
legible hook for Roblox discovery; the economy is what retains.

---

## The three pillars `[LOCKED]`

Every system must serve at least one. Anything serving none gets cut.

| Pillar | Player fantasy | Primary loop |
|---|---|---|
| **MINE** | "I built this myself" | Extract → refine → bank → upgrade |
| **TRADE** | "I understand this market" | Produce → list → arbitrage → specialize |
| **RAID** | "I took that from someone" | Scout → breach → escape → flex |

**All three can reach the top of the ranked ladder solo.** A pure miner,
a pure trader, and a pure raider are each viable. Hybrid play is more
efficient, not required. (`07-decisions.md § Q9`)

---

## Target audience

- Roblox core demographic, skewing young. Assume a meaningful share under 13.
- Mobile-first. Design every interaction for touch and low-end devices.
- Two distinct player types must both be served:
  - **Casuals** who want a satisfying tap-collect loop and never touch PvP
  - **Deep players** who want market mastery, raid skill, and collector status

## Session shape `[LOCKED]`

**Target: 45+ minutes.** This is a deep-session game.

Consequence: the loop needs multiple activity types with different
rhythms. A single-activity game fatigues at ~15 minutes.
(Structure in `02-core-loop.md § Session structure`)

---

## Non-negotiable design rules

These are load-bearing. Breaking any one of them has historically killed
games in this genre. Rationale for each is in `07-decisions.md`.

### R1 — Identity is never lootable `[LOCKED]`
Players tolerate losing **stuff**. They quit over losing **identity**.

- **Lootable:** resources, components, sealed cases, unlearned blueprints, items in transit
- **Never lootable:** cosmetics, base structures, equipped gear, rank, titles, trophies, Tech Path unlocks, Blueprint Mastery
  (Base structures are never *looted*; at vault tiers 8–10 they can be *destroyed* — see R2 and `07-decisions.md § D23`.)

### R2 — Nothing is permanently destroyed, except at the top `[LOCKED, revised D23]`
Raiders steal and temporarily disable. Workshops can be knocked offline;
they never de-tier. The punishment is **time and momentum**, not erasure
— **at vault tiers 1–7.**

**Elite tiers (8–10) are the sole exception:** a raider may permanently
destroy one targeted structure per successful raid. High-tier players
opted into this by climbing; new players never encounter it. **Cosmetics
and equipped gear are never destroyed, at any tier — R1 always wins.**
See `07-decisions.md § D23`.

### R3 — Money buys convenience and looks, never power or safety `[LOCKED]`
- Robux may buy: cosmetics, bank capacity, automation convenience, extra slots, fast travel, VIP servers
- Robux-bought cosmetics live in a **separate swap-only pool** and can never be converted into Credits or anything Credits buy (`07-decisions.md § D65`)
- Robux may **never** buy: raid immunity, protection beyond the bank, combat advantage, admin powers, Research Scrap, Fragments, or anything gating progression
- Automation is always **slower per minute** than active play at equal investment

### R4 — Depth is invisible in the first ten minutes `[LOCKED]`
The FTUE teaches exactly one thing: tap the glowing thing. Tech Path,
market, Patterns, ranks, crews, cases — none of it appears until the player
has already committed. Any leak forward is a launch-blocking bug.

### R5 — The server is the only authority `[LOCKED]`
All resource grants, Grade/Condition/Pattern rolls, theft math, lockpick
results, and market transactions are computed and validated server-side.
A theft economy is an exploit magnet. This is architecture, not a
later hardening pass.

### R6 — New players cannot be farmed `[LOCKED]`
Raid matchmaking is banded by the **highest of current vault tier,
lifetime peak vault tier, or gear score** (D66) — so rebirthing or buying
top gear never drops a strong player into the beginner band. A max-tier
player is not offered a beginner as a target. 48-hour new-account shield
and the 30-minute post-raid shield, neither of which **any event
(including Blackout) can remove** (D67, D75). Raid cost (`Breach
Charges`) makes low-value targets structurally unprofitable.

### R7 — No randomness behind real money `[LOCKED]`
Cases and keys use gameplay-only currency that Robux cannot purchase at
any remove — and Robux-bought goods can never be sold or traded into it,
because Robux cosmetics trade only inside their own swap pool (D65). This
keeps the entire case loop outside Roblox's Paid Random Items policy.
(`09-research.md § Platform policy`)

### R8 — Teas and consumables never boost raw combat damage `[DEFERRED to S2]`
Consumables make players richer and faster, not stronger in a fight.
A buffed veteran out-earning a newcomer is progression. A buffed veteran
one-shotting them is churn.

---

## Design rubric `[LOCKED as process]`

Re-scored against every draft version. Catches regressions — it is how
v4's comprehension regression was caught.

| # | Criterion | Weight | A 10 looks like |
|---|---|---|---|
| 1 | 10-Second Comprehension | ×3 | Player knows what to do with zero text |
| 2 | First-Reward Speed | ×3 | Meaningful reward inside 60 seconds |
| 3 | Session Progress Felt | ×2 | Visible change every 2–3 minutes |
| 4 | Cross-Session Pull | ×3 | Something waiting on login |
| 5 | Variable Reward | ×2 | Same action, unpredictable payoff |
| 6 | Social Interdependence | ×2 | Other players make the game better |
| 7 | Flex Visibility | ×2 | Status readable at a glance |
| 8 | Loss Tolerance | ×3 | Loss creates tension, not quitting |
| 9 | New Player Safety | ×3 | Beginners aren't farmed |
| 10 | Monetization Fairness | ×2 | Spending ≠ winning |
| 11 | Exploit Resistance | ×2 | Cheating is structurally hard |
| 12 | Content Velocity | ×2 | Updates reuse existing systems |

**Max 300.**

### Score history

| Version | Score | Notes |
|---|---|---|
| v3 | 244 / 300 (81%) | Baseline |
| v4 | 261 / 300 (87%) | Seeds, seasons, raid cost, pickaxe tree |
| v4.2 | not yet rescored | Tech tree, 4-resource model, farming added |

### Standing weaknesses

- **#11 Exploit Resistance (6/10)** — lowest score. An economy + theft +
  randomized high-value drops is the most attractive exploit target
  possible. Mitigation is R5, enforced from day one.
- **#1 Comprehension** — under constant pressure as systems accumulate.
  Protected only by R4. Every new system must be checked against it.
- **#8 Loss Tolerance** — the bank system is the best answer available,
  but this remains a game where a young player can lose things.
