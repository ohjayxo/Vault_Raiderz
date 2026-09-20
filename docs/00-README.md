# Vaultbreakers — Design Document Set

**Current version:** v5.6
**Last updated:** 2026-09-19
**Platform:** Roblox (Luau, Roblox Studio)
**Status:** Pre-production. Nothing built yet. Vertical slice design locked (v5.5); ready to begin the build (`13-build-guide.md`).

---

## What this is

A Roblox game combining a production economy, a global player market, and
a PvP raid layer. The one-line pitch:

> **"Mine it. Bank it. Or lose it."**

Positioned as a deep-session (45+ min) experience in the lane occupied by
Blox Fruits / Fisch / 99 Nights in the Forest, not the short-session lane
of Steal a Brainrot — while borrowing Steal a Brainrot's proven theft
tension for its hook.

---

## Reading order

Mirrors `12-nexus.md § Reading Order`, which is canonical. If the two
ever disagree, nexus wins and this list should be corrected.

1. `00-README.md` — this file: index, conventions, glossary
2. `12-nexus.md` — the map: concept ownership, file dependencies, where
   new material belongs. It tells you where to find what you need
   instead of reading every file start to finish.
3. `01-pillars.md` — pitch, non-negotiable rules, rubric
4. `02-core-loop.md` — how it actually plays, minute one to minute forty-five
5. `03-progression.md` — how players advance
6. `04-world-content.md` — what fills the world
7. `05-items.md` — what exists in the world
8. `06-economy.md` — how value moves
9. `07-decisions.md` — **why things are the way they are** (read before changing anything)
10. `10-roadmap.md` — what ships when, and what is explicitly out of scope

Reference as needed, not part of the main sequence:
- `08-questions.md` — open design questions (pull only the relevant section)
- `09-research.md` — competitive analysis and sourced platform facts (pull only the source backing a claim)
- `11-claude-usage-guide.md` — which Claude model/effort to use for which task
- `13-build-guide.md` + `14-claude-code-prompts.md` — the build phase: how to turn the slice into a playable alpha

---

## File index

| File | Covers |
|---|---|
| `00-README.md` | This file. Index, conventions, glossary. |
| `01-pillars.md` | Pitch, pillars, audience, non-negotiable rules, design rubric |
| `02-core-loop.md` | FTUE spec, session shape, world, combat, chase, bank/exposed, raiding |
| `03-progression.md` | Workshops, tech tree, research, blueprints, mastery, rebirth, ranks, seasons |
| `04-world-content.md` | Mobs, bosses, loot tables, Riftfall, caches, events, farming |
| `05-items.md` | Item taxonomy, resources, rarity rolls, gear, cosmetics, cases, blueprints |
| `06-economy.md` | Currencies, market, sinks/faucets, trade safety, monetization |
| `07-decisions.md` | Locked decisions + rationale + what was rejected |
| `13-build-guide.md` | How to build the vertical slice: setup, architecture rules, build steps 0–14, playtesting |
| `14-claude-code-prompts.md` | Paste-ready Claude Code prompts, one per build step |
| `08-questions.md` | Open questions with both sides argued |
| `09-research.md` | Competitor analysis, retention benchmarks, platform policy |
| `10-roadmap.md` | Vertical slice, launch scope, season plan, risks |
| `11-claude-usage-guide.md` | Claude model and effort choices by project phase (process, not design) |
| `12-nexus.md` | File map, concept ownership index, dependency graph, origination rules, number registries |

---

## Conventions

### Status tags

Every section and major claim carries a status tag. **Do not treat an
untagged or `[PROPOSED]` item as a requirement.**

| Tag | Meaning |
|---|---|
| `[LOCKED]` | Decided by the project owner. Do not change without explicit instruction. Rationale is in `07-decisions.md`. |
| `[PROPOSED]` | Suggested during design, **not yet confirmed**. Open to change. |
| `[DEFERRED]` | Deliberately parked for a later season or version. Not in launch scope. |
| `[OPEN]` | Actively undecided. See `08-questions.md` for the argued options. |
| `[CUT]` | Considered and rejected. Kept so it isn't re-proposed. Reason in `07-decisions.md`. |

### Placeholder numbers

**Every number in this document set is a placeholder unless marked
otherwise.** They were derived from design reasoning and genre
comparison, never from playtesting or balance simulation.

Marked inline as: `[PH]`

Example: `Offline raids take 8% [PH] of exposed resources`

Rule: **do not build a balance spreadsheet against `[PH]` values.** They
exist to communicate intent and relative scale, not absolute tuning. They
become real only after the vertical slice is playtested.

### Cross-references

Concepts are defined in exactly one file and referenced elsewhere. If you
find a concept fully defined in two files, that is a bug — the definition
belongs in its owning file, and the other should be reduced to a pointer.
`12-nexus.md § The Concept Ownership Index` is the canonical table of
which file owns which concept — check it before writing a definition
anywhere.

Reference format: `see 05-items.md § Cases`

### Numbering

R (rules), D (decisions), and Q (questions) numbers are issued from
`12-nexus.md § Number Registries`. Check it before adding a new one and
update it after. Q-numbers are never reused.

---

## Glossary

| Term | Meaning |
|---|---|
| **The Exchange** | Central safe-zone hub. Market, NPC vendors, public Workshop I, leaderboards. |
| **Homestead Ring** | Zone containing player plots. Raidable. |
| **The Reaches** | Contested mid-tier resource zone. Full PvP. |
| **The Rift** | Deepest, most dangerous zone. Bosses, legendary materials. |
| **Vault Core** | The structure that defines banked storage capacity. |
| **Banked** | Resources inside the Vault Core. Cannot be stolen. Capacity-capped. |
| **Exposed** | Resources above bank capacity. Fully stealable. |
| **Stone / Ore** | Common resources. Stone builds; Ore makes tools, Workshops, defenses. |
| **Voltstone** | Scarce resource; trickles from Ore nodes, rich in the Reaches. Elite gear and Workshop III. |
| **Riftsalt** | Contested-zone-only resource. Used only for Breach Charges. |
| **Grade** | Rarity roll on harvested resources. Drives value multiplier. |
| **Condition** | Cosmetic wear roll on gear/cosmetics (0.00–1.00). The CS "float" analog. |
| **Pattern** | Roll (1–1000) on gear/cosmetics, formerly called "Seed" (D93). The CS "paint seed" analog. |
| **Unstable Finish** | A cosmetic where Pattern dramatically changes appearance. Where the collector meta lives. |
| **Credits** | Gameplay currency for market, vendors, Cases, Keys. Never Robux-purchasable. |
| **Research Scrap** | Progression-only currency. Cannot be bought. Feeds the Tech Path. Converts to a cosmetic currency at season end. |
| **Marks** | Working name (proposed) for the cosmetic-only currency Scrap converts into each season. |
| **Rarity tier** | Cosmetic tier, Common → Mythic. Separate from Grade (resources) and Condition/Pattern. |
| **Robux pool** | Robux-bought cosmetics; swap-only for same-tier Robux cosmetics, never for Credits. |
| **Vaultbreaker Level** | Proposed permanent account level; gates system reveals (e.g. trading). |
| **Workshop** | Physical tiered structure in a player's base. Gates research and crafting. |
| **Tech Path** | The scrap-purchased branching unlock tree. Replaces a class system. |
| **Research Bench** | Consumes a looted item + scrap to permanently learn its blueprint. |
| **Fragment** | Loot-only gate item required to build Workshop II and III. |
| **Component** | Loot-only crafting input with no recipe. |
| **Riftshard** | Riftfall-only Component. Input for Fabrication-branch cosmetic recipes. |
| **Seed pack** | Crop-seed item, foraged from wild plants or found in caches. |
| **Pattern** | Formerly "Seed" — the 1–1000 collector roll on gear/cosmetics (D93). |
| **Reputation tracks** | Miner/Trader/Raider XP tracks; cosmetic-and-title rewards only (D81). |
| **Vaultbreaker Level** | Permanent account level fed by Reputation; gates trading at Level 10 (D82). |
| **Marks** | Cosmetic-only currency Research Scrap converts to at season end (D68, D84). Account-bound. |
| **Gear score** | Pickaxe tier + upgrade-node count; used only for raid matchmaking band (D66, D92). |
| **Breach Charge** | Consumable required to raid. Crafted from Riftsalt. |
| **Riftfall** | Broadcast world event. Contested loot drop at a visible location. |
| **Case** | Sealed container with random contents. Tradeable, stealable while sealed. |
| **Key** | Consumable required to open a Case. Gameplay currency only. |
| **The Chase** | The vulnerable escape phase after a raider grabs loot. |
| **Crew** | Player group, 2–4 members. |

---

## How to use this set with a new session

**Inside the Claude Project:** all files are already loaded. Don't paste
anything — just ask. The session should consult `12-nexus.md` to route
the question and read only the owning files.

**Outside the Project** (another tool, a collaborator): share
`00-README.md` and `12-nexus.md` first, then `01-pillars.md`, then only
the files the nexus Concept Ownership Index points to. Always include
`07-decisions.md` before asking for changes — it prevents re-litigating
settled questions.
