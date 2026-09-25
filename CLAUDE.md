REWORK PHASE R1 IS ACTIVE (REWORK.md v1.3). Read REWORK.md before any
work. For the map, WORLD_MAP.md is the spec. Where REWORK.md and
docs/ disagree, REWORK.md wins. docs/ is frozen: do not edit it.
Build R1 items in the order of the REWORK.md §14 status list, not by
item number. Log build-time calls in REWORK.md §18, one line each.

# CLAUDE.md — Vault Raiderz (Roblox, Luau, Rojo)

You are building the **vertical slice** of Vault Raiderz, a Roblox game.
The owner (Josh) is new to Roblox development: explain what you're doing
in plain language, plan before building, and tell him exactly how to test
each change in Studio.

## Source of truth
- Design lives in `docs/` (files `00`–`14`). **Edit `docs/` only with
  double confirmation from Josh**: he asks or agrees, you show the exact
  files and text, he confirms again, then you edit. It's also managed in a
  separate design project, so remind him to make the same change there.
- Start from `docs/12-nexus.md` to find which file owns a topic.
- Build process: `docs/13-build-guide.md`. Step prompts:
  `docs/14-claude-code-prompts.md`.
- Your own notes/estimates go in `docs-build/`, never `docs/`.
- If a design file and this file disagree, the design file wins — tell
  Josh about the conflict.

## Scope wall
Build only what's in `docs/10-roadmap.md § Vertical Slice` (D107). Never
build: the global Exchange, Cases/Keys, Condition/Pattern rolls, seasons,
Marks, Workshop II/III, Fragments, bosses beyond the Scav Captain, world
events, farming, pets, rebirth, Robux purchases. If a task seems to need
one, stub it and say so.

## Design gaps
If the docs don't say how something should behave: **stop and ask**. Give
the file/section, 2–3 options and your pick. Never invent game design.
Missing *numbers* are different: add them to Config as `-- [PH] invented`
and list them in your step summary.

## Non-negotiables (full text: docs/01-pillars.md)
- R1 Identity (cosmetics, equipped gear, rank, titles, Tech Path) is never lootable
- R2 Nothing is permanently destroyed below vault tier 8 (tiers 8–10 aren't in the slice)
- R3 Robux buys convenience/looks, never power or safety (no Robux in the slice)
- R4 Depth is invisible in the first 10 minutes (FTUE hides systems)
- R5 **The server is the only authority**
- R6 New players can't be farmed (band matchmaking, shields)
- R7 No randomness behind real money
- R8 Consumables never boost combat damage

## Architecture rules
- `src/server` = all logic and authority. `src/client` = input, UI,
  visuals only. `src/shared` = Config, types, remote definitions.
- One service module per system in `src/server/Services`. Only a
  system's own service mutates its data.
- Clients send **intents**, never values. The server validates distance,
  ownership, cooldowns, existence and rate limits on every remote.
- All remotes are defined in `src/shared/Remotes.luau`.
- Every tunable number lives in `src/shared/Config.luau` with a comment
  naming its doc section and D#. No magic numbers in logic.
- Random rolls (Grade, loot) happen only on the server; odds never
  replicate to clients.
- Player data: ProfileStore (session-locked). Crew Vaults: their own
  session-locked store.
- MemoryStore = authority for short-lived shared state (presence, raid
  locks), always with TTLs, error handling and exponential backoff.
  MessagingService is only a hint, never the source of truth.
- Offline raids use the presence + raid lock + ProfileStore message
  pattern in `docs/13-build-guide.md § Part D`. Don't improvise another.
- Server announcements go through the one prioritized BroadcastQueue (D58).

## Greybox contract
- Gameplay objects are Models with a CollectionService tag and
  attributes for their data.
- Each has a `Hitbox` part (code uses this) and a `Visual` folder
  (players see this). **Code never reads or writes `Visual`.**
- Placeholder art only: parts, default rigs, built-in effects.

## Code style
- `--!strict` at the top of every file; type everything.
- Small, readable modules. Comments explain *why*, citing doc sections.
- Studio-only debug commands are gated behind `RunService:IsStudio()`.
- No `wait()`; use `task.wait`, `task.spawn`, `task.delay`.
- Wrap every DataStore/MemoryStore call in `pcall` with retries/backoff.

## Working style
1. Read the docs the prompt names.
2. Post a plan (files to create/change, how it works, risks, anything
   undefined). Put a **Setup** box at the top, with one line of reasoning
   for each item:
   - **Model + effort**: what Josh should set (`/model`, `/effort`) and
     whether his current setting is fine. Follow
     `docs/11-claude-usage-guide.md` and `docs/13-build-guide.md` →
     Model choice. Map "Extended thinking" to `/effort high`.
   - **Workflow**: solo, one subagent, or a workflow. For a workflow,
     give its shape (e.g. finders → verifiers), roughly how many agents,
     the model/effort per stage, and a rough cost. Only run it if Josh
     says "use a workflow".
   - Keep it short. If the current setup is fine, say so in one line.
   Wait for approval.
3. Build.
4. Tell Josh exactly how to test it (Play vs Clients and Servers, how
   many players, what to click, what he should see).
5. At the end: summary, invented `[PH]` values, and anything to bring
   back to the design project.
6. Commit only when Josh says the step's checklist passes.
