# Handoff to the design project: Chase "grip" + raid-time respawn (2026-09-23)

**For:** Claude in the claude.ai design project.
**From:** Claude Code (the build, `~/vaultbreakers`). Read
`docs-build/claude-ai-handoff.md` first if your docs are behind: the repo
registry is **D1–D114, next free D115** (ask Josh to confirm before using it).
**Status:** Josh's preferred direction, **not built**. It changes a `[LOCKED]`
rule, so it needs a decision here first. Then Claude Code edits `docs/` with
Josh's double confirmation and builds it.

---

## 1. The problem (found in Studio testing after build step 8)

Three rules combine badly:

1. **One hit knocks the loot loose.** `02-core-loop.md § The Chase` point 5
   `[LOCKED]`: "Any player who lands a hit ... knocks the loot loose."
2. **A plot's only exit is its bridge.** D113 (Main Street) gives every plot
   one bridge, and drop-in clearance stops anyone jumping in or out.
3. **You respawn on your own plot ~5 s [PH] after dying.** Build step 5
   design-gap answer (in `docs-build/design-changes.md`, not in `docs/`).

The results:
- **Bridge camping.** An online owner stands at the end of their own bridge.
  A raider carrying loot has to pass them, and one hit ends the raid. The
  raider has to *kill* the owner first, but the owner only has to *tap* the
  raider.
- **Killing the defender doesn't help.** If the raider kills the owner, the
  owner respawns on their own plot 5 s later, right beside the raid, and
  taps the carrier.

Online defense is meant to be real (`§ Theft math` pushes raiders toward
online raids). The problem is the imbalance, one tap against a kill that
achieves nothing.

Current numbers (all `[PH]`, in `Config`): 100 HP; pickaxe damage 10 / 13 /
16 / 20 by tier; 3-hit combo multipliers 1 / 1 / 1.6 (a Wooden combo ≈ 36);
armor −5–20% damage; carry speed 60% (~9.6 studs/s); escape radius 140
studs; a Chase lasts ~12–15 s.

## 2. Options weighed

| Option | Verdict |
|---|---|
| Full kill to drop loot | Fixes camping, but turns the Chase into a duel. Loses the third-party "anyone can crash it" moment (point 5's stated reason), gear decides too much, escorts matter less, and finisher knockback pushes the carrier toward escape. Kept in reserve if grip proves too easy to defend. |
| Carrier grace period after grab (~3 s) | Doesn't help against a camper at the bridge end. |
| Rely on existing counters (Shock Trap, Smoke before grab, escort) | Too weak against a defender who respawns in 5 s. |
| **Grip limit + raid-time respawn (chosen direction)** | See §3. |

## 3. Proposal (Josh's preferred direction)

### 3a. Grip limit: loot drops after a set amount of damage, not one hit
While carrying loot, the carrier has a **grip** value, separate from health.
Damage the carrier takes from other players' hits reduces grip. **At 0, the
loot is knocked loose** (same result as today's point 5: it returns to the
owner). **Grip = 30 damage [PH]**, about one Wooden 3-hit combo.

Why: one tap no longer ends a raid, so camping one spot fails. Anyone who
lands a real combo still crashes the raid, so point 5's server-wide chaos
survives. It scales with the Combat branch (damage) and armor (damage
taken), so gear matters without deciding everything. One number to tune.

### 3b. Raid-time respawn: die during a raid on your base → respawn on Main Street
If you die **while your own base is being raided**, you respawn at the
**Main Street spawn**, not on your plot. Walking back takes ~15–20 s [PH,
estimate] naturally. Otherwise respawn is unchanged (your own plot).

Why: killing the defender now buys the raider real time, so "kill the guard,
then raid" becomes a plan, and the counters that already exist (Shock Trap,
Smoke, escort) start to matter. A walk back was preferred over a longer death
timer, which feels bad.

## 4. Questions to decide here

1. **Grip value:** 30 [PH], or scale it (e.g. with the victim's vault tier)?
2. **Does grip recover** while the carrier isn't being hit, or only reset
   on a new grab?
3. **What counts toward grip:** player hits only (proposal), or also
   defense damage (Guard Drone zaps) and Scavs? The escort's hits never
   count (D101), as today.
4. **Does the carrier see their grip** (a bar under the carry marker)? Do
   attackers see it? (Suggest: the carrier and the owner.)
5. **Raid-time respawn scope:** only the base owner, or later their crew
   (step 11) too? Only while the raid is active (breach → escape/fail)?
6. **Does the owner's death during the raid also end their "defending"
   in any other way?** (Suggest no, only the spawn point changes.)

## 5. Suggested doc edits (after the decision; exact text TBD by you)

- **New decision D115** (confirm the number with Josh): "Chase grip limit +
  raid-time respawn", amends `§ The Chase` point 5, marked `[LOCKED]` with
  the grip value `[PH]`.
- `02-core-loop.md § The Chase` point 5: "Any player who lands a hit knocks
  the loot loose" → "Hits from other players (except the raider's own
  escort, D101) wear down the carrier's **grip**; at 0 the loot is knocked
  loose and returns to the owner's vault (D115). Grip = 30 damage [PH]."
- `02-core-loop.md § The Chase`, the "Point 5 is the key design choice"
  paragraph: keep, adding that a real combo (not a stray tap) is needed.
- `02-core-loop.md § Combat` (or a new "Death and respawn" line): record the
  build's death rule (respawn ~5 s [PH] on your own plot, lose nothing),
  plus "**while your base is being raided, you respawn on Main Street**
  (D115)".
- `12-nexus.md` registry → D1–D115 (next D116) + version row;
  `10-roadmap.md` / `00-README.md` version rows as usual.

## 6. What Claude Code will build once decided

RaidService: a per-raid grip value, lowered on `CombatService.Hit` by the
damage actually dealt (after armor), knocked loose at 0; RaidView gains
grip for the UI. CombatService respawn: `PlotService.getSpawnCFrame` returns
the Main Street spawn while a raid on that player's base is active. Config:
`Raiding.GripDamage = 30 -- [PH]`.
