# 12 — Nexus (Oversight & Interconnectivity) `[LOCKED as process]`

**This file is infrastructure, not game design.** It contains no pitch,
no mechanics, no numbers. Its only job is to keep the other 11 files
honest — one canonical home per concept, a map of what depends on what,
and rules for where new material is born. Read this like you'd read
`01-pillars.md § Design rubric`: a process file that gets re-consulted,
not a chapter you finish once.

---

# READING ORDER `[LOCKED]`

**This is the canonical reading order.** `00-README.md § Reading order`
mirrors it; if the two ever disagree, this file wins.

1. `00-README.md` — index, conventions, glossary
2. **`12-nexus.md`** (this file) — the map
3. `01-pillars.md` — pitch, non-negotiable rules, rubric
4. `02` → `10`, in numeric order — the chronological build-up (loop, then
   progression, then world, then items, then economy, then decisions,
   then roadmap)

**Reference as needed, not part of the main sequence:**
`08-questions.md` (pull up only the section relevant to the question at
hand) and `09-research.md` (pull up only the source backing a specific
claim).

**Why nexus sits before `01-pillars`, not after it:** everything in
`01-pillars.md` onward assumes you already know where things live. Read
it after the pitch and you're navigating blind; read it before, and the
pitch lands with a map already in hand.

---

# THE CONCEPT OWNERSHIP INDEX — the map to maps `[LOCKED]`

**Rule: a concept is defined in exactly one file.** Every other mention
is a pointer (`see 05-items.md § Cases`), never a re-explanation. If a
concept is fully explained in two files, that's a bug — collapse it to
one definition and a pointer. (This restates and enforces the
Cross-references rule already in `00-README.md`; nexus is where it's
actually operationalized.)

| Concept | Canonical file | Pointers live in |
|---|---|---|
| Pitch, pillars, non-negotiable rules (R1–R8), rubric | `01-pillars.md` | Everywhere — every mechanic should trace back to a pillar or a rule |
| FTUE spec, session structure, world zones, combat, Bank/Exposed, raiding, the Chase, defenses, automation | `02-core-loop.md` | `05-items` (taxonomy stealable column), `06-economy` (sinks), `08-questions` Q20–22 |
| Workshops, Tech Path, Research Bench, Blueprints (full spec), Mastery, Rebirth, ranks/seasons | `03-progression.md` | `05-items` (Fragments, Blueprints taxonomy summary — **must stay a pointer**), `06-economy` (scrap sink table) |
| PvE ladder, mobs/bosses, loot buckets, Scav Waves, World Caches, dynamic events (Riftfall etc.), Farming, Teas | `04-world-content.md` | `02-core-loop` (zone table), `05-items` (Grade roll examples), `10-roadmap` (Season Plan headline) |
| Item taxonomy, Resources, the three rarity rolls (Grade/Condition/Seed), Gear, Cosmetics, Cases, Keys, Components, Fragments | `05-items.md` | `02-core-loop` (world zones), `03-progression` (Fragments gate), `06-economy` (Case/Key triangle) |
| Currencies, the Exchange/market, sinks & faucets, trade safety, market manipulation, monetization | `06-economy.md` | `01-pillars` (R3), `05-items` (taxonomy), `09-research` (platform policy) |
| **Why** any locked decision was made, and what was rejected | `07-decisions.md` | Every other file states *what*; only this one states *why + rejected alternatives* |
| Vertical slice, launch scope, season plan, known risks, build order, version history | `10-roadmap.md` | `01-pillars` (rubric scores), `03-progression` (season mechanics vs. roadmap cadence — see § Known drift risks) |
| Unresolved, genuinely-arguable design questions | `08-questions.md` | Nowhere else — once answered, the entry moves to its Answered table and a `D#` appears in `07-decisions.md` |
| Sourced external facts (competitor data, platform policy, benchmarks) | `09-research.md` | Every file that cites a stat should point here rather than restating the source inline |
| Index, conventions, status tags, glossary | `00-README.md` | Everywhere — status tags (`[LOCKED]` etc.) are defined once, there |
| File map, dependency graph, origination rules | `12-nexus.md` | — (this is the pointer target, not a pointer itself) |
| Build process: toolchain, code architecture rules, build-step checklists, playtest plan | `13-build-guide.md` | `14-claude-code-prompts.md` (prompts point back to it), repo `CLAUDE.md`. **Never restates game design** — only points into `01`–`10` |

---

# THE DEPENDENCY GRAPH — "if you touch X, check Y" `[LOCKED]`

Concepts that live in one file still have edges reaching into others.
This table exists so an edit doesn't silently orphan a number or
contradict a rule three files away.

| If you change... | Also check... |
|---|---|
| A resource (add/remove/reweight Stone/Ore/Voltstone/Riftsalt) | `02-core-loop` (progressive reveal), `06-economy` (Riftsalt rule), `03-progression` (Voltstone gates Workshop III), `07-decisions` D14 |
| Tech Path structure or costs | `05-items` (Fragments), `06-economy` (scrap sink table), `08-questions` Q44–48 |
| Raid theft percentages, timing, or the Chase | `06-economy` (sinks table), `07-decisions` D1/D3/D4/D5, `09-research` (Rust warning it's modeled against) |
| Cases/Keys model | `06-economy` (Case/Key triangle + Monetization), `07-decisions` D15, `08-questions` Q24–27, `09-research` (platform policy) |
| A `[LOCKED]` rule (R-number) or decision (D-number) | The rubric in `01-pillars` (does a score assumption still hold?), `10-roadmap` (does scope still match?) |
| Anything currently `[OPEN]` in `08-questions.md` | Once answered: add a `D#` to `07-decisions.md`, move the `08-questions.md` entry to its Answered table, update the status tag in the mechanic's home file, then update the registries below |
| Season cadence or content | `03-progression § Ranked Ladder & Seasons` **and** `10-roadmap § Season Plan` both currently hold season material — see § Known drift risks |
| Anything touching monetization | `01-pillars` R3, `06-economy § Monetization`, `07-decisions` rationale for R3, `09-research § Platform policy` — **re-verify the policy source before building**, it's flagged as fast-moving |

---

# FILE ORIGINATION RULES — where new material is born `[LOCKED]`

When a new idea comes up in conversation, route it *before* writing
anything, using this order:

1. **Is it a rule that, if broken, has historically killed games in this
   genre?** → `01-pillars.md § Non-negotiable design rules`, next `R#`
2. **Is it how value moves — currency, market, sinks, faucets?** →
   `06-economy.md`
3. **Is it a thing that exists — an item, resource, cosmetic, gear
   piece?** → `05-items.md`
4. **Is it a creature, boss, world event, or place?** →
   `04-world-content.md`
5. **Is it how a player gets stronger or deeper over time?** →
   `03-progression.md`
6. **Is it moment-to-moment play — combat, raiding, session flow,
   FTUE?** → `02-core-loop.md`
7. **Is it a decision being locked right now, with a rejected
   alternative worth recording?** → `07-decisions.md` gets the entry
   (`D#`); the mechanic's home file gets the `[LOCKED]` tag and a
   one-line pointer back — never the full rationale duplicated in place
8. **Is it genuinely unresolved, arguable both ways?** →
   `08-questions.md`, next unused `Q#` (never reuse or renumber a
   retired one, even if it's cut)
9. **Is it an external, sourced fact — a competitor stat, a platform
   policy, a benchmark?** → `09-research.md`, must be independently
   re-verifiable later
10. **Is it about *when* something ships or what's explicitly out of
    scope?** → `10-roadmap.md`
11. **Does it touch reading order, file boundaries, or cross-file
    integrity itself?** → `12-nexus.md` (this file)

If it fits more than one row, it usually means the concept needs to be
split: the *what* goes in its home file, the *why/rejected* goes in
`07-decisions.md`, the *open debate* (if any) goes in `08-questions.md`.
That three-way split is the normal shape, not an exception.

---

# NUMBER REGISTRIES `[UPDATE THIS SECTION AS YOU GO]`

Single source of truth for the next unused number, so two sessions never
issue the same one by accident. **Update these three lines whenever a
new R/D/Q is added anywhere in the set** — it's the cheapest possible
insurance against a collision.

| Series | Home file | Currently in use | Next available |
|---|---|---|---|
| **R (non-negotiable rules)** | `01-pillars.md` | R1–R8 | **R9** |
| **D (locked decisions)** | `07-decisions.md` | D1–D112 | **D113** |
| **Q (open questions)** | `08-questions.md` | up to Q70 | **Q71** |

---

# OPERATING INSTRUCTIONS FOR ANY CLAUDE SESSION `[LOCKED]`

1. **Load `00-README.md` and this file first**, every time — both are
   short, and together they replace needing to read all 11 files for a
   narrow question.
2. **Use the Concept Ownership Index to route the question**, then pull
   in only the 1–3 files that actually own the relevant material. Don't
   default to reading the whole set.
3. **Before proposing a change to anything `[LOCKED]`**, say explicitly
   that it's locked and confirm the user actually wants to revisit it —
   this is `00-README.md`'s existing rule; nexus doesn't loosen it.
4. **Before adding new material, run it through § File Origination
   Rules** rather than guessing which file feels right.
5. **After resolving an `[OPEN]` question or adding a new rule/decision
   in conversation**, remind the user to: (a) update the status tag in
   the mechanic's home file, (b) add the entry to `07-decisions.md` with
   what was rejected, (c) move the `08-questions.md` entry to its
   Answered table if applicable, (d) bump the relevant counter in §
   Number Registries above.
6. **Before touching anything in § Dependency Graph's left column**,
   check its right column first — don't edit one file and assume the
   others are unaffected.

---

# KNOWN DRIFT RISKS `[OPEN — watch list]`

Places where the same material currently has more than one home, or is
close to it. Not bugs yet — just where duplication is most likely to
creep in on a future edit.

- **Seasons.** `03-progression.md § Ranked Ladder & Seasons` holds the
  reset/persist mechanics; `10-roadmap.md § Season Plan` holds cadence
  and headline content. Both are legitimate, different concerns — but an
  edit to one without checking the other is how these drift apart.
  **Now higher-risk:** resets are staggered by tier (D72), with a
  mid-season Tier 3 reset — `10-roadmap § Season Plan` now mentions it
  (v5.5); keep the two in sync.
- **Cosmetic trading pools.** D65's two-pool rule is defined in
  `05-items § Two trading pools` but constrains `06` (monetization),
  `01` (R3/R7), and any future trade-up or pet mechanic.
- **"Pattern" vs. crop seeds.** Resolved by D93 (the roll is now
  "Pattern"), but `09-research` and older roadmap history still say
  "Seed" for the CS comparison — any new text should say "Pattern."
- **Riftsalt / raid-gating.** Touched in `05-items` (source), `06-economy`
  (the Case/Key-style "can't be a safe farmer and a raider" rule),
  `02-core-loop` (Breach Charge precondition), and `07-decisions` D14
  rationale. Highest reference-count of any single resource — the one
  most likely to go stale in one place after being updated in another.
- **Blueprints.** `05-items.md` already handles this correctly (explicit
  "Fully specified in `03-progression.md § Blueprints`. Summary for
  taxonomy purposes.") — flagged here as the *model* to copy when
  resolving future duplication, not a problem.

---

# VERSION HISTORY

| Version | Date | Changes |
|---|---|---|
| v1 | 2026-09-19 | Initial nexus — reading order, concept ownership index, dependency graph, origination rules, number registries, operating instructions, drift watch list |
| v1.1 | 2026-09-19 | Registry corrected (D1–D53, next D54); Housekeeping section removed — README reading order already synced |
| v1.2 | 2026-09-19 | Registry: D1–D74 (next D75), Q up to Q70 (next Q71). Note: D54–D64 had been assigned in 08/02/06 without 07 entries; entries now written. Added drift risks: staggered resets, trading pools, Seed naming |
| v1.3 | 2026-09-19 | Registry: D1–D106 (next D107). 32 decisions (D75–D106) written for the Part 1/2/3/4 discussion round: shield/matchmaking fixes, Reputation tracks + Vaultbreaker Level locked, Marks named, rarity tiers locked, rebirth deferred to S2+, Pattern rename (resolves Q70), NPC price decay, bounties, trade-ups, trade holds, Name Tags, pets, raid escort, resonance nodes, NPC contracts + Collection Log, provenance tags, raid path map, Community Beacon. |
| v1.4 | 2026-09-19 | Registry: D1–D109 (next D110). Slice locked (D107–D109). Seed drift risk marked resolved; Seasons drift note updated. |
| v1.5 | 2026-09-19 | Added `13-build-guide.md` and `14-claude-code-prompts.md` (build phase) to the Concept Ownership Index. Repo-root `CLAUDE.md` is a build artifact, not a design file. |
| v1.6 | 2026-09-19 | Registry: D1–D110 (next D111). D110 resolves the offline-production slice gap. |
| v1.7 | 2026-09-20 | Registry: D1–D111 (next D112). D111 (pickaxes untradeable, skins tradeable) supersedes D21; made during the build phase. |
| v1.8 | 2026-09-20 | Registry: D1–D112 (next D113). D112 adds armor to the slice (amends D107, D92). |
