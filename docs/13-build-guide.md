# 13 — Build Guide: the Vertical Slice (Alpha)

**Status:** `[LOCKED as process]` — written for v5.6.
**Scope:** the vertical slice only (`10-roadmap.md § Vertical Slice`,
`07-decisions.md § D107`). Nothing outside that table gets built here.

**Rule for this file:** it never restates game design. Every mechanic,
number and rule lives in `01`–`10`; this file only says *how to build it*
and points there. If this file and a design file disagree, the design
file wins.

**Companion files:**
- `14-claude-code-prompts.md` — paste-ready prompts, one per build step
- `CLAUDE.md` — goes in the root of your code repo; Claude Code reads it
  automatically every session

---

# PART A — THE BIG PICTURE

## What you're building
A playable, greybox (placeholder-art) version of the slice: mine, bank,
build, fight Scavs, raid, get chased, trade, research, and form crews.
It is "done" when it can run the playtest in `§ Part F` and measure the
success criteria in `10-roadmap.md § Success criteria before expanding`.

## Who does what

| Piece | Job |
|---|---|
| **You** | Decide, playtest, report what's broken or not fun, commit progress |
| **Claude Code** | Writes and edits the Luau code files on your computer |
| **Rojo** | Copies those code files into Roblox Studio live as they change |
| **Roblox Studio** | Runs the game so you can play it; holds the map and placeholder parts |
| **Git + GitHub** | Saves every version so a bad change can always be undone |
| **This Claude.ai project** | Design decisions. If the build hits a design gap, it comes back here |

## Greybox first
All art is placeholder (Studio parts, default characters, built-in
effects). Code only cares what an object *is* (its tag), never what it
looks like, so real art drops in later without code changes. See
`§ Part D — The greybox contract`.

**One exception:** the step-0 mobile performance test uses stand-in shapes
with realistic triangle counts, because grey blocks would make a phone
look faster than it will be with real art.

---

# PART B — ONE-TIME SETUP

Do these in order. Budget an afternoon. Screenshots aren't included — if
a screen doesn't match, ask Claude (chat or Claude Code) and describe what
you see.

## B1. Accounts
- **Roblox account** with Studio access (you have this).
- **Claude plan that includes Claude Code** — Pro, Max, Team, Enterprise,
  or a Console account. The free Claude.ai plan does not include Claude
  Code.
- **GitHub account** (free) at github.com.

## B2. Install Git
- **Windows:** install Git for Windows (git-scm.com). It's optional for
  Claude Code but recommended — it gives Claude Code a Bash shell, and you
  need Git for version history anyway.
- **Mac:** open Terminal and run `git --version`; if it isn't installed,
  macOS offers to install it.

Then set your name once (in a terminal):
```
git config --global user.name "Josh"
git config --global user.email "you@example.com"
```

## B3. Install VS Code (your code viewer)
You won't be writing much code by hand, but you'll want to read it.
Install **Visual Studio Code**, then from its Extensions panel install:
- **Luau Language Server** (by JohnnyMorganz) — understands Roblox code
- **Rojo** (by evaera) — Rojo menu and status inside VS Code

## B4. Install Claude Code
Native installer (recommended):
- **Windows (PowerShell):** `irm https://claude.ai/install.ps1 | iex`
- **Mac:** `curl -fsSL https://claude.ai/install.sh | bash`

Check it worked: `claude --version`. Then run `claude` once and log in
through the browser.

## B5. Install Rokit, then Rojo
**Rokit** is the toolchain manager that installs and pins Rojo per
project (it replaced Aftman/Foreman as the community default).

1. Install Rokit using the instructions for your OS on the Rokit GitHub
   page (github.com/rojo-rbx/rokit).
2. You'll add Rojo to the project in `B7` — Rokit will pin the version
   there so it never drifts. Rojo **7.6.0** is current as of this writing.

> **Why Rojo and not Studio's built-in Script Sync?** Roblox shipped Script
> Sync as a full release in June 2026, and it's fine for editing scripts
> in an external editor. Rojo is still the better fit here: it treats the
> code files as the source of truth, which is what Git and Claude Code
> need. Tooling is locked to Rojo + Luau (`10-roadmap.md § Build Order`).

## B6. Studio basics (15 minutes, before anything else)
Open Studio, create a **Baseplate**, and find these:

| Thing | Where | What it's for |
|---|---|---|
| **Explorer** | View tab | Tree of everything in the game. Rojo fills `ServerScriptService`, `ReplicatedStorage`, `StarterPlayer` |
| **Properties** | View tab | Settings for whatever you select |
| **Output** | View tab | **Errors show up here.** Keep it open always |
| **Play** (F5) | Home / Test tab | Play as one player |
| **Clients and Servers** | Test tab | Starts a local server with 2–4 test players in separate windows — how you test raids, trading and crews |
| **Device emulator** | Test tab | Previews phone screen sizes for mobile UI |

## B7. Create the project folder
In a terminal:
```
mkdir vaultbreakers
cd vaultbreakers
git init
```
Then:
1. Make a `docs/` folder and copy **all** design files (`00`–`14`) into
   it. Claude Code reads them from there.
2. Put `CLAUDE.md` (the companion file) in the folder root.
3. Run `claude` in this folder and paste **Prompt S1** from
   `14-claude-code-prompts.md`. It creates the Rojo project, the folder
   layout, the Config module, and installs ProfileStore.
4. Install the Rojo Studio plugin: `rojo plugin install`, then restart
   Studio.
5. Create a **private** GitHub repository, and push (Claude Code can walk
   you through `git remote add` and `git push` if you ask).

## B8. Create and publish the place — do this before step 1
DataStores and MemoryStores **only work in a published place**, including
during Studio testing.
1. In Studio: File → Publish to Roblox → create a new experience named
   Vault Raiderz. Keep it **private**.
2. Home → Game Settings → Security → turn on **Enable Studio Access to API
   Services**.
3. Save the place file somewhere outside the repo (Rojo syncs code into
   it; the place file holds the map and placeholder parts).

**Studio-quota warning:** MemoryStore limits scale with player count, and
in Studio you are the only player, so the quota is tiny. Studio testing
has the same limits as production, but a user-count-based quota can be
very small there. Code must use backoff and never spam MemoryStore in
loops.

---

# PART C — HOW A WORK SESSION GOES

Every build session follows the same loop:

1. **Terminal 1:** `cd vaultbreakers` → `rojo serve`
2. **Studio:** open the place → Rojo plugin → **Connect**
3. **Terminal 2:** `cd vaultbreakers` → `claude`
4. Paste the next prompt from `14-claude-code-prompts.md`
5. Claude Code **plans first** (the prompts ask it to). Read the plan. If
   it describes a mechanic you don't recognize from the docs, say so.
6. Let it build. Code appears in Studio automatically through Rojo.
7. **Playtest** using that step's checklist in `§ Part E`. Use Clients and
   Servers for anything multiplayer.
8. Report problems in plain words: "When I raid with player 2, the loot
   trail doesn't show and Output says ___." Paste the red error text.
9. When the checklist passes, run **Prompt R (review)**, then commit:
   ask Claude Code to "commit this step" or run `git add -A` then
   `git commit -m "Step N: ..."`, then `git push`.
10. Type `/clear` before starting the next step so old context doesn't
    confuse the new one.

**Model choice** (`11-claude-usage-guide.md`): Sonnet by default. Use Opus
for steps 1, 7 and 8 (data layer, raiding, raid protections) — the
exploit-sensitive architecture where a subtle bug costs the most.

**If something breaks badly:** `git status` shows what changed;
`git restore .` throws away uncommitted changes and returns to the last
commit. This is why you commit after every passing step.

**If Claude Code hits a design gap** (the docs don't say what should
happen), it's instructed to stop and ask rather than invent. Bring the
question back to this Claude.ai project and decide it. Then have Claude
Code make the same edit in `docs/` (double confirmation, see CLAUDE.md), or
copy the file in, but only after the design project has every repo-side
change logged in `docs-build/design-changes.md`; otherwise the copy
overwrites them.

---

# PART D — ARCHITECTURE RULES

These are the rules `CLAUDE.md` enforces. You don't need to write any of
this — it's here so you can recognize when code is going off the rails.

## Folder layout
```
vaultbreakers/
├─ CLAUDE.md
├─ default.project.json      (Rojo map: folders → Studio locations)
├─ rokit.toml                (pins Rojo version)
├─ docs/                     (design files — Claude Code edits only with double confirmation)
└─ src/
   ├─ server/                → ServerScriptService   (all game logic, all authority)
   │  ├─ Services/           (one module per system: Nodes, Vault, Raid…)
   │  └─ Packages/           (ProfileStore)
   ├─ client/                → StarterPlayerScripts   (input, UI, visuals only)
   └─ shared/                → ReplicatedStorage      (Config, types, remote definitions)
```

## Server authority (R5)
- The client only ever **asks** ("I want to mine this node"). The server
  checks everything — distance, cooldowns, ownership, whether the thing
  exists, rate limits — then decides and tells clients the result.
- **No gameplay value ever comes from the client.** Not damage, not
  amounts, not Grade rolls, not prices.
- Every remote has a server-side rate limit. Impossible requests get
  logged (anomaly detection — `10-roadmap.md § Known Risks #1`).

## One Config module for every number
Every `[PH]` value from the docs lives in `src/shared/Config.luau`, each
with a comment naming its doc section and `D#`. Tuning never touches
game logic. When the docs don't give a number, Claude Code adds a clearly
labeled `-- [PH] invented` value there, and lists it in its step summary.

## Player data
- **ProfileStore** (by loleris) for every player profile: it auto-saves,
  and its **session locking** prevents two servers editing the same
  player at once — the main cause of item duplication in trading games.
- The plot, resources (Banked/Exposed), Scrap, Credits, Tech Path,
  blueprints, crew membership, Reputation XP (Level is derived from it,
  D80) all live in the profile.
- Small flags are bitpacked (D80); inactive plots archive (D55). Full
  compression of large fields waits for real data (D54).
- Crew Vaults are **separate** stores (a crew isn't one player), with
  their own locking; use the Crew Vault rules in
  `03-progression.md § Crew Vault` (D90, D91).

## The hard part: raiding a player who isn't on your server
Offline raids (`02-core-loop.md § Theft math`) mean one server takes
resources out of a profile another server might load at any moment. The
required pattern:

1. **Presence key** in MemoryStore: each online player's server writes a
   short-lived "I'm online on server X" key and refreshes it.
2. **Offline raid only if no presence key exists**, and the raiding server
   takes a **raid lock** on the victim (MemoryStore, short TTL).
3. Raid math uses the victim's last saved Exposed values (read-only view).
4. The theft is delivered to the victim's profile as a **message**
   (ProfileStore's messaging feature), which is applied before the victim
   can act on their next login. A victim logging in mid-raid waits for the
   lock to clear.
5. The raider's loot stays **in transit** (the Chase) and only credits on
   escape; knocked-loose loot never leaves the victim.

This is the single most exploit-sensitive system in the slice. Build it
in step 7 with Opus, and run Prompt R on it twice.

MemoryStore is the authority for short-lived shared state; MessagingService
is only ever a hint (`06-economy.md § The hard architectural constraint`).
Current MemoryStore quotas: requests are capped at 1000 + 120 × concurrent
users per minute and memory at 64 KB + 1.2 KB per user, with a 32 KB limit
per value. Re-verify these before step 1 — `09-research.md` flags them as
fast-moving.

## The greybox contract
- Every gameplay object is a **Model** with a **CollectionService tag**
  (`ResourceNode`, `VaultCore`, `Defense`, `Workshop`…) and **attributes**
  for its data (`NodeType`, `Grade`…).
- Inside each model: a `Hitbox` part (what the code uses) and a `Visual`
  folder (what players see). **Code never touches `Visual`.**
- Replacing a grey cube with a real model = swap the contents of `Visual`.
  No code changes.
- Build-budget costs (D57) are read from attributes, so real art's cost
  gets updated in one place.

## Anti-exploit baseline (every step)
- Server-side distance and line-of-sight checks on mining, combat, and
  pickups
- Cooldowns enforced on the server, not the client UI
- Mining/income rate anomaly logging
- Combat hits validated server-side (the client's swing is only a request)
- Trade confirmation and 5-second lock (`06-economy.md § Trade Safety`)

## Analytics
Use Roblox's `AnalyticsService` for funnel and custom events from day one,
so the slice can measure D1, session length and churn-after-first-raid
(`10-roadmap.md § Success criteria`). Log the FTUE steps as a funnel.

---

# PART E — THE BUILD STEPS

Order matches `10-roadmap.md § Build Order` (D108). Each step: goal →
docs → playtest checklist. Prompts are in `14-claude-code-prompts.md`.
**Don't start a step until the previous one passes its checklist and is
committed.**

### Step S — Scaffold (Prompt S1)
Repo, Rojo project, folders, Config, ProfileStore, a "hello" script.
- [ ] `rojo serve` runs; Studio connects
- [ ] Pressing Play prints the hello message in Output
- [ ] Committed and pushed to GitHub

### Step 0 — Estimate + mobile performance spike (Prompts 0A, 0B)
**Docs:** `10-roadmap.md § Known Risks #3`, `09-research.md § Rendering &
Mobile Performance Budget`.
- [ ] 0A produced a written estimate per step, with the riskiest steps named
- [ ] 0B scene: your base + several neighbor bases with realistic
      triangle counts + particle effects
- [ ] Tested on a **real, cheap phone** (publish privately, join from the
      Roblox app), not just the emulator
- [ ] Recorded the frame rate. If it's bad, bring the numbers back to the
      Claude.ai project before step 4 — base size and LOD rules may change

### Step 1 — Server-authoritative data layer (Opus)
**Docs:** `01-pillars.md § R5`, `05-items.md § Taxonomy`, D55, D80, `§ Part D`.
- [ ] Join → profile loads; leave → saves; rejoin → same data
- [ ] Two test players have separate data
- [ ] Studio "Clients and Servers" with 2 players: no errors in Output
- [ ] Debug command (Studio-only) to print a player's profile

### Step 2 — Node collection + Grade rolls
**Docs:** `05-items.md § Resources`, `§ Roll 1 — Grade`, `§ Node respawn`,
`§ Rich-node landmarks`, `§ Vaultborn announcement`, D46.
- [ ] Tapping a node mines it; resources appear in a debug HUD
- [ ] Grades roll on the server; odds are **never** sent to the client
- [ ] Nodes deplete and respawn per the docs
- [ ] Spamming the mine remote from a test script gets rate-limited and logged

### Step 3 — Vault Core + Bank/Exposed
**Docs:** `02-core-loop.md § Bank vs Exposed` (including special cases).
- [ ] Banked vs Exposed meter visible
- [ ] Mined resources land in Exposed; using the Vault Core banks best-first up to the cap; Prismatic/Vaultborn auto-bank if room
- [ ] Scrap has its own small bank cap

### Step 4 — Base building + build budget
**Docs:** `02-core-loop.md § Base / Home`, `§ Build budget` (D57),
`§ Server sharding` (D56, D79) — sharding can be stubbed to "one
neighborhood per server" for now, but the band metric code path must exist.
- [ ] Place walls, gates and the Vault Core on your plot; can't build on
      others' plots
- [ ] Budget blocks placement past the limit
- [ ] Base persists across rejoin

### Step 5 — Combat + pickaxe + upgrade tree
**Docs:** `02-core-loop.md § Combat`, `§ Pickaxe upgrade tree`, `§ Combat
feel`, `§ Gadgets`; `05-items.md § Gear score` (D92).
- [ ] 3-hit combo, knockback; fights resolve in the target time
- [ ] Hits validated on the server
- [ ] Upgrade points spend into three branches; respec costs resources
- [ ] Gear score computed server-side, never shown to players

### Step 6 — Defenses + Scav Waves + Scav Captain
**Docs:** `02-core-loop.md § Defenses`, `04-world-content.md § Scav Waves`
(D59, D87), `§ Loot table structure`, `§ The PvE ladder` (Homestead row
only), D107 (Captain loot to the defender).
- [ ] Defense slots are limited; charges deplete and refill with resources
- [ ] A Scav Wave attacks, defenses trigger, failing costs Exposed only
- [ ] Captain drops loot via the four-bucket table
- [ ] Wave ceiling works (force many waves in a test)

### Step 7 — Raiding + lockpick + Chase + raid escort (Opus)
**Docs:** `02-core-loop.md § Raiding`, `§ Lockpick skill model`, `§ Theft
math`, `§ The Chase`, `§ Raid escort` (D101), `§ Raid log path map`
(D105), `§ Tiered raid interaction` (tiers 1–7 only in the slice), and
`§ Part D — The hard part` above.
- [ ] Online raid: breach → lockpick → grab Exposed → escape in the window
- [ ] Carrier is slowed, gadgets disabled, marked server-wide
- [ ] Any player's hit (not the escort's) knocks loot loose back to the owner
- [ ] Escort can body-block but can't grab
- [ ] ~20% of stolen goods destroyed in transit
- [ ] **Offline raid** on a player who left: works, and when they rejoin
      their Exposed is correctly reduced and the raid log shows the path
- [ ] **Try to break it:** victim rejoins mid-raid; raider leaves mid-Chase;
      two raiders hit the same offline base. No duplication, no negative
      resources.

### Step 8 — Breach Charges, Riftsalt, raid band, shields (Opus)
**Docs:** `05-items.md § The Riftsalt rule`, `02-core-loop.md §
Preconditions`, `01-pillars.md § R6`, D66, D67, D75, D79, D92.
- [ ] Riftsalt only spawns in the Reaches; charges are crafted from it
- [ ] No charges → can't raid
- [ ] Out-of-band targets can't be raided (test with a high-gear player vs
      a fresh account)
- [ ] 48-hour new-account shield and 30-minute post-raid shield work

### Step 9 — NPC selling, direct trade, Level/Reputation gate
**Docs:** `06-economy.md § Two tiers of selling`, `§ NPC price decay`
(D94), `§ Zero-chat trade` (D61), `§ Trade Safety`, `§ Access gating`
(D82); `03-progression.md § Reputation tracks`, `§ Level`.
- [ ] Selling to the NPC gives Credits; price drops per sale, resets daily
- [ ] Reputation XP from mining/trading/raiding; Level updates
- [ ] Direct trade locked until Level 10 [PH]
- [ ] Trade window: both sides see exactly what swaps; 5-second confirm lock
- [ ] Trade history saved; below-market warning shows

### Step 10 — Workshop I, Tier 1 Tech Path, Research Bench, Common Blueprints
**Docs:** `03-progression.md § The Workshop` (Tier I only), `§ The Tech
Path` (Tier 1, permanent — D72), `§ Tech Path respec` (D109), `§ Node
visibility`, `§ Research Bench`, `§ Blueprints` (Common only).
- [ ] Workshop I placeable; opens the Tier 1 tree (vertical mobile UI — D60)
- [ ] Nodes cost Scrap; prerequisites enforced; full tree visible (D108)
- [ ] Research Bench consumes an item + Scrap and teaches its blueprint
- [ ] Respec refunds 50% [PH]

### Step 11 — Crews
**Docs:** `03-progression.md § Crews` (all subsections), `06-economy.md §
Crew Vault`, D25, D90, D91, D109.
- [ ] Invite/accept with no chat
- [ ] Crew Vault: leader full access, members capped withdraw
- [ ] Shared T1 nodes only after 24h [PH] tenure (use a debug clock to test);
      leaving revokes access
- [ ] Disband returns deposits, splits the remainder

### Step 12 — Offline production (one Harvester Drone)
**Docs:** `02-core-loop.md § Automation` (D110), `§ Session structure`
(Collection phase).
- [ ] Craft one Harvester Drone and place it on your plot
- [ ] Log out, log back in later → "while you were away" payout
- [ ] Payout is slower per minute than active play (R3) and computed from
      server timestamps, not client time
- [ ] No Robux option anywhere

### Step 13 — Analytics
**Docs:** `10-roadmap.md § Success criteria`.
- [ ] FTUE funnel steps, session length, first-raid-loss events logging
- [ ] You can see them in the Creator Dashboard analytics

### Step 14 — FTUE polish (last, hardest)
**Docs:** `02-core-loop.md § FTUE spec` and `§ FTUE hard rules` — treat as
a spec, second by second.
- [ ] Fresh account: node glowing within 10 seconds, no text before 2:30
- [ ] Free cosmetic granted at the Vault build (a simple, no-roll pickaxe
      skin is enough — Condition/Pattern rolls are out of the slice)
- [ ] First raid is the derelict NPC vault and always succeeds
- [ ] Nothing from `03`, `04 § events`, `05 § cases/patterns` or `06`
      visible during FTUE
- [ ] Watch someone who's never seen the game play it without helping them

---

# PART F — PLAYTESTING THE ALPHA

1. **Friends and family first**, private server. Watch, don't explain.
   Write down every moment they're confused.
2. **Real phones.** Most of the audience is mobile.
3. **Before any public test:** fill out the experience's content maturity
   questionnaire in the Creator Dashboard, and re-check the chat and
   social policies (`09-research.md § Chat & Social Age-Gating`) — the
   audience is young.
4. **Measure** against `10-roadmap.md § Success criteria` (D1 ≥ 20%,
   session ≥ 15 min, churn after first raid loss).
5. **Do not add features while D1 is below 15%.** Fix what's there.
6. Bring findings back to this Claude.ai project: tuning goes into Config;
   design changes go through the normal decision process (`12-nexus.md`).

---

# PART G — WHEN YOU'RE STUCK

| Problem | Fix |
|---|---|
| Studio doesn't show new code | Rojo plugin says Connected? Is `rojo serve` still running in Terminal 1? |
| "DataStore request was rejected" / API errors in Studio | Place not published, or Studio API access not enabled (`§ B8`) |
| MemoryStore errors in Studio only | Studio's quota is tiny (`§ B8`); make sure code backs off. It'll behave better in a real server |
| Claude Code seems confused or repeats mistakes | `/clear`, then re-paste the step prompt with the error text |
| A change broke everything | `git restore .` (uncommitted) or ask Claude Code to revert to the last commit |
| Something works alone but breaks with 2 players | It's a server-authority or replication bug — ask Claude Code to run Prompt R on that system |
| The docs don't say what should happen | Stop. Bring it to the Claude.ai project |

---

# PART H — SCOPE DISCIPLINE

The out-of-slice list in `10-roadmap.md § Vertical Slice` is a hard wall:
no global Exchange, Cases/Keys, Condition/Pattern rolls, seasons, Marks,
Workshop II/III, Fragments, bosses beyond the Scav Captain, events,
farming, pets, rebirth. If a step seems to need one of these, it doesn't —
stub it or ask.
