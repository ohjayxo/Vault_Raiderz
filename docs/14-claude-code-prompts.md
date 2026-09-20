# 14 — Claude Code Prompts (Vertical Slice)

**Status:** `[LOCKED as process]` — written for v5.6.
**How to use:** one prompt per build step, in order. Before each step,
type `/clear` in Claude Code, then paste the whole prompt block. Checklists
and context for each step are in `13-build-guide.md § Part E`.

Every prompt assumes `CLAUDE.md` is in the repo root and the design
files are in `docs/`. Claude Code reads `CLAUDE.md` automatically.

**Model:** Sonnet unless the step says Opus. Switch with `/model`.

---

## Standing prompts (use any time)

### Prompt R — Review (run after every step, before committing)
```
Review everything changed in this step as a hostile exploiter and as a
Roblox server-authority auditor. Check against CLAUDE.md and
docs/01-pillars.md R1–R8. Specifically look for:
- any value, amount, roll or decision taken from the client
- remotes without server-side rate limits or validation
- duplication paths (leaving mid-action, rejoining, two servers, two
  players acting at once)
- DataStore/MemoryStore calls without error handling or backoff
- magic numbers that belong in src/shared/Config.luau
- code that reads or writes a model's Visual folder
- anything built that is outside the vertical slice
List problems by severity with file and line. Fix the High ones, then
show me what you fixed. Don't change design behavior while fixing.
```

### Prompt B — Bug report
```
Bug: [what I did] → [what I expected] → [what happened instead].
Output window says: [paste red error text, or "nothing"].
Test setup: [Play solo / Clients and Servers with N players].
Find the root cause before changing anything, explain it in two
sentences, then fix it. Don't rewrite unrelated code.
```

### Prompt G — Design gap
```
Stop coding. Write up the design gap you hit: what the docs say (with
file + section), what they don't say, 2–3 options, and which you'd pick
and why. I'll take it to the design project. Don't implement any option.
```

### Prompt C — Commit
```
Summarize this step in one line, list any [PH] values you invented in
Config.luau, then commit everything with message "Step N: <summary>" and
push.
```

---

## Prompt S1 — Scaffold the project
```
Read CLAUDE.md, then docs/00-README.md, docs/12-nexus.md and
docs/13-build-guide.md (Part B and Part D). Don't write game features yet.

Set up the project:
1. rokit.toml pinning Rojo 7.6.0 (run `rokit init` / `rokit add
   rojo-rbx/rojo@7.6.0` as needed) and install it.
2. default.project.json mapping src/server → ServerScriptService,
   src/client → StarterPlayer.StarterPlayerScripts, src/shared →
   ReplicatedStorage.Shared, per Part D.
3. The folder layout from 13-build-guide.md § Part D.
4. src/shared/Config.luau — empty sections with headers for each slice
   system in docs/10-roadmap.md § Vertical Slice. Every future number
   goes here with a doc/D# comment.
5. src/shared/Remotes.luau — a single place that defines every
   RemoteEvent/RemoteFunction by name, created by the server.
6. Download ProfileStore (single ModuleScript, MadStudioRoblox/ProfileStore
   on GitHub) into src/server/Packages.
7. A server script that prints "Vaultbreakers server up" and a client
   script that prints "client up".
8. .gitignore suitable for a Rojo project (ignore *.rbxl, *.rbxlx,
   sourcemap outputs, OS junk).
9. A selene.toml or luau-lsp config if it helps type checking; use
   --!strict in every new file.

Plan first and show me the plan. After I approve, do it, then tell me
exactly how to run `rojo serve`, connect Studio, and confirm the two
print messages.
```

## Prompt 0A — Engineering estimate
```
Read docs/10-roadmap.md (Vertical Slice, Build Order, Known Risks) and
docs/13-build-guide.md Part E. Don't write code.

For each build step 1–14: list the modules/systems it needs, the riskiest
part, what could make it take 2–3x longer, and a rough size (S/M/L/XL).
Then name the three steps most likely to blow up, and suggest what to cut
first if the total is too big — cutting from the bottom of the build
order only, never steps 1–8. Save it as docs-build/estimate.md
(new folder; never edit docs/).
```

## Prompt 0B — Mobile performance spike
```
Read docs/09-research.md § Rendering & Mobile Performance Budget and
docs/10-roadmap.md § Known Risks #3.

Build a throwaway test scene (in src/server/PerfSpike, easy to delete
later) that spawns: one player base plus 8 neighboring bases on floating
islands, each built from stand-in meshes/parts approximating realistic
triangle counts for a mid-tier base (state your assumption), a dozen
resource nodes with particle emitters, and a few default-rig NPCs
walking around. Add a client FPS + memory readout on screen.

Keep everything tagged per the greybox contract so nothing here leaks
into real systems. Tell me how to publish privately and join from a
phone to read the numbers. Then help me interpret the results against
the budget in the docs.
```

## Prompt 1 — Data layer  (use Opus)
```
Read CLAUDE.md, docs/01-pillars.md (R5, R6), docs/05-items.md § Taxonomy,
docs/02-core-loop.md § Bank vs Exposed and § Plot lifecycle,
docs/07-decisions.md D54, D55, D80, D90, and 13-build-guide.md Part D
(Player data, The hard part).

Build the server-authoritative data layer:
- PlayerDataService on ProfileStore: session-locked profiles, a typed
  profile template covering every slice field (resources Banked/Exposed,
  Research Scrap with its separate cap, Credits, plot, base pieces, gear,
  pickaxe upgrades, Tech Path T1, learned Common blueprints, crew id,
  Reputation tracks + Level, lifetime peak vault tier, shields,
  lastActive), a version number and a migration hook.
- Bitpack the small flags (D80). Plot archiving (D55): store lastActive
  and a stub archive/restore path; no real archiving job yet.
- A Studio-only debug command to print a profile.
- A PresenceService stub (MemoryStore key per online player, refreshed,
  short TTL, with backoff) — needed later for offline raids.
- Everything that mutates data goes through service methods; nothing
  else writes to profile tables.

Plan first. Flag anything the docs leave undefined instead of inventing
it. Then implement and tell me how to verify with 2 players in Clients
and Servers.
```

## Prompt 2 — Nodes and Grade rolls
```
Read docs/05-items.md § Resources, § The Riftsalt rule, § Rich-node
landmarks, § Node respawn, § Progressive reveal, § Roll 1 — Grade,
§ Odds are not published in-game, § Vaultborn announcement,
§ Auto-bank protection; docs/02-core-loop.md § World Structure;
docs/06-economy.md § Broadcast priority queue (D58).

Slice resources are Stone, Ore and Riftsalt only (Riftsalt only in the
small Reaches area). Build:
- A greybox Homestead island and a small Reaches island (placeholder
  parts), with tagged ResourceNode models (Hitbox + Visual).
- NodeService: server-validated mining (distance, cooldown, rate
  limit), depletion and respawn per the docs, server-side Grade rolls
  with odds only in server Config.
- Vaultborn announcement through a minimal BroadcastQueue module that
  implements D58's priority rule (later steps add raid alerts to it).
- A temporary debug HUD showing resources.
Plan first, then build. Tell me how to test the rate limit.
```

## Prompt 3 — Vault Core and Bank/Exposed
```
Read docs/02-core-loop.md § Bank vs Exposed (all of it) and
§ Buildable elements (Vault Core).

Build VaultService: Vault Core capacity, overflow to Exposed, the
separate smaller Research Scrap cap, Prismatic/Vaultborn auto-bank if
room. Add a Banked/Exposed HUD meter (hidden until the FTUE reveals it
later — make its visibility controllable). Plan first, then build.
```

## Prompt 4 — Base building and build budget
```
Read docs/02-core-loop.md § Base / Home, § Build budget (D57),
§ Server sharding (D56, D79), § Tiered raid interaction (tiers 1–7);
docs/05-items.md § Gear score (for the band metric).

Build:
- PlotService: each player gets a plot; placement only on your own plot;
  server-validated grid/rotation; pieces saved in the profile.
- Walls, gates and Vault Core placement (greybox pieces, tagged,
  with budget cost as an attribute).
- Build budget enforced per vault tier (numbers in Config).
- Sharding: stub as one neighborhood per server, but implement the
  band-metric function (highest of vault tier, lifetime peak, gear
  score) now, because raiding and sharding both use it.
- A simple mobile-friendly build UI (big buttons).
Plan first, then build.
```

## Prompt 5 — Combat, pickaxe, upgrades
```
Read docs/02-core-loop.md § Combat (all), § Pickaxe upgrade tree,
§ Combat feel, § Gadgets; docs/05-items.md § Gear, § Gear score (D92);
docs/01-pillars.md R8.

Build CombatService: pickaxe as both tool and weapon, 3-hit combo,
knockback, server-validated hits (the client only requests a swing;
the server checks range, timing, facing). Health and respawn. Upgrade
points spent across Extraction/Combat/Mobility with respec costing
resources. The four gadgets as single-use items. Gear score computed
server-side and never sent to clients. Default rigs and a stick-and-block
pickaxe are fine. Plan first, then build.
```

## Prompt 6 — Defenses, Scav Waves, Scav Captain
```
Read docs/02-core-loop.md § Defenses; docs/04-world-content.md § The PvE
ladder (Homestead row only), § Mobs vs bosses, § Loot table structure,
§ Scav Waves, § Concurrent wave ceiling (D59), § Higher-tier mobs can
raid too (D29, D87); docs/07-decisions.md D107 (Captain loot goes to the
defender).

Build DefenseService (limited slots, charges that deplete and refill with
resources, the six defenses as greybox), NPC Scavs using default rigs
with simple server-side AI, ScavWaveService (scaled to base tier, failing
costs Exposed only, server-wide concurrent cap with a queue), and the
Scav Captain with the four-bucket loot table. Plan first, then build.
Include a Studio-only command to trigger a wave.
```

## Prompt 7 — Raiding, lockpick, the Chase, escort  (use Opus)
```
Read docs/02-core-loop.md § Raiding (all), § The Chase, § Raid escort
(D101), § Raid log path map (D105), § Tiered raid interaction (tiers 1–7
only), § HUD Priority (D64); docs/06-economy.md § Broadcast priority
queue; docs/01-pillars.md R1, R2, R5, R6; 13-build-guide.md Part D
"The hard part".

Build RaidService end to end:
- Breach (charges will come in step 8 — gate it behind a function that
  step 8 fills in), lockpick timing minigame scaled by vault tier
  (speed-based, never fail-locked), grab from Exposed only, 90s escape
  window.
- The Chase: carrier slowed, gadgets disabled, owner alerted (including
  offline via raid log), server-wide marker + trail, any player's hit
  knocks loot back to the owner, ~20% destroyed in transit.
- Raid escort: a friend can body-block but can't carry or grab.
- Raid log with a path-line map.
- Offline raids using EXACTLY the presence + raid-lock + ProfileStore
  message pattern in 13-build-guide Part D. Loot is in transit until
  escape; the victim's debit is applied before they can act on login.
- Tiers 5–7: knock a defense or Workshop offline 15 min [PH].
Plan first — and in the plan, list every duplication/race scenario you
can think of and how the design prevents each. Then build. Then run
Prompt R on RaidService twice.
```

## Prompt 8 — Breach Charges, Riftsalt, band, shields  (use Opus)
```
Read docs/05-items.md § The Riftsalt rule; docs/02-core-loop.md
§ Preconditions, § FTUE hard rules (rule 6); docs/01-pillars.md R6;
docs/07-decisions.md D66, D67, D75, D79, D92.

Build: Breach Charge crafting from Riftsalt; raiding requires and
consumes charges; the band check (highest of current vault tier,
lifetime peak, gear score) on every raid attempt, server-side; the
48-hour new-account shield from first login; the 30-minute post-raid
shield; both immune to any future "drop all shields" event (add the
exemption flag now even though Blackout isn't in the slice). Plan first,
then build. Give me a Studio-only way to fast-forward shield timers.
```

## Prompt 9 — NPC selling, direct trade, Level/Reputation
```
Read docs/06-economy.md § Currencies, § Two tiers of selling, § NPC price
decay (D94), § Access gating (D82), § Zero-chat trade (D61), § Trade
Safety; docs/03-progression.md § Reputation tracks (D81),
§ Vaultbreaker Level (D82); docs/05-items.md § Taxonomy (what's
tradeable).

Build:
- NPC buyer: Credits for resources, per-player price decay per sale,
  daily reset.
- ReputationService: Miner/Trader/Raider XP from server-validated
  actions; Level = the sum; cosmetic/title rewards stubbed.
- Direct trade window (no chat needed): both sides' offers visible,
  5-second lock before Confirm, atomic server-side swap (no dupes if a
  player leaves mid-trade), trade history, below-market warning, locked
  until Level 10 [PH].
Plan first — include how the trade stays atomic. Then build.
```

## Prompt 10 — Workshop I, Tech Path T1, Research Bench, Blueprints
```
Read docs/03-progression.md § The Workshop (Workshop I only), § The Tech
Path (Tier 1), § Structure, § Branches (Tier 1 branches), § Tech Path
respec (D37, D109), § Staggered tier reset (Tier 1 = permanent),
§ Node visibility, § Research Bench, § Blueprints (Common tier only);
docs/06-economy.md § No indirect Credits → Scrap route (D69).

Build WorkshopService and TechPathService: placeable Workshop I, the
Tier 1 tree as data in Config (shape from the docs' example tree, costs
[PH]), prerequisite chains, Scrap costs, full tree visible, one vertical
collapsible mobile UI (D60), 50% [PH] respec refund. Research Bench:
consume item + Scrap → learn its Common blueprint. Recycling → Scrap
with the market-acquired flag at heavy loss. Plan first, then build.
```

## Prompt 11 — Crews
```
Read docs/03-progression.md § Crews (every subsection), docs/06-economy.md
§ Crew Vault, docs/07-decisions.md D25, D49, D50, D61, D90, D91, D109.

Build CrewService: 2–4 players, invite/accept UI only; Crew Vault as its
own session-locked store with leader full access, members capped daily
withdrawal [PH], per-member deposit tracking; disband returns each
member's deposits and splits the remainder; shared Tier 1 Tech Path
nodes after 24h [PH] tenure, revoked on leaving (Prototypes never
shared — not in slice anyway). Add a Studio-only clock offset so tenure
can be tested. Plan first — including what happens if two servers touch
the Crew Vault at once. Then build.
```

## Prompt 12 — Offline production
```
Read docs/02-core-loop.md § Automation and § Session structure, and
docs/07-decisions.md D110.

Build one craftable Harvester Drone (greybox, tagged per the greybox
contract, costs in Config as [PH]) that the player places on their plot.
While the player is offline it produces resources; on login show a
"while you were away" payout. Rules: always slower per minute than active
play (R3), capped [PH], computed on the server from saved timestamps
(never trust client time), and the payout lands in the normal
Banked/Exposed flow. No Robux version — the gamepass is out of the slice.
Plan first, then build.
```

## Prompt 13 — Analytics
```
Read docs/10-roadmap.md § Success criteria and docs/02-core-loop.md
§ FTUE spec.

Add AnalyticsService instrumentation: an onboarding funnel with one step
per FTUE row, session start/end, first raid attempted, first time raided,
and whether a player returns after their first raid loss. Keep all event
names in one module. Tell me where to see them in the Creator Dashboard.
Plan first, then build.
```

## Prompt 14 — FTUE
```
Read docs/02-core-loop.md § First-Time User Experience, § FTUE spec and
§ FTUE hard rules — treat the table as a spec, second by second. Also
docs/01-pillars.md R4.

Build FTUEService for brand-new profiles only:
- Spawn facing a glowing node with a pulsing arrow; second node type at
  0:10–0:45; progress ring to BUILD VAULT.
- Vault placement payoff + a free cosmetic (a simple no-roll pickaxe
  skin — Condition/Pattern rolls are out of the slice).
- A single Scav that dies in 2–3 hits and drops loot.
- At 2:30 reveal the Banked/Exposed meter with the one line of text.
- A derelict NPC vault with an easy, guaranteed-success lockpick.
- Hide every system listed in hard rule 5 until FTUE completes.
- No text before 2:30.
Hook every step into the analytics funnel from step 13. Plan first,
then build. Then give me a checklist to watch a brand-new player go
through it.
```
