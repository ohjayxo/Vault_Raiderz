# REWORK.md — Vault Raiderz Phase R1 (the minimum playable rework)

**Status:** ACTIVE · **Version 1.3** (2026-09-24). Written in the claude.ai
design project from *Vault Raiderz: The Rework Plan* v1.2 (PDF). v1.1 added
the Rich Vein, a simple Level, a cheap-phone gate and status checkboxes.
v1.2 added a model and effort for every step (§14.1). **v1.3 replaces the
Main Street map with The Quarry** (spec in the companion file
`WORLD_MAP.md`), splits R1-08 into R1-08a/b/c and builds the map right
after R1-01, turns the Plaza into a truce square, moves the Scav Camp to
the Gate, makes the Burrow the only Scav spawn, and adds respawn rules.
Every call is logged in §18.
**Goes in:** the repo root as `REWORK.md` (replacing v1.2), next to
`CLAUDE.md` and `WORLD_MAP.md`.
**Authority:** where this file and `docs/` disagree, **this file wins**.
For the map's positions, shapes, spawns and dressing, **`WORLD_MAP.md` is
the spec** (§19). `docs/` is **frozen** during the rework: don't edit it.
**Numbers:** every number marked `[PH]` is a starting placeholder. Put it in
`src/shared/Config.luau` with a comment naming the section of this file
(for example `-- REWORK §5.2 [PH]`, or `-- WORLD_MAP §3 [PH]` for map
numbers). Tune freely; no decision entry needed.

---

## 0. How to use this file

### For Josh
1. Paste **Prompt RW-START** (§17) once, after `/clear`. It sets up the
   branch, the feature switches and the `CLAUDE.md` pointer.
2. Then do the R1 items in §14 **in order, one per session**: `/clear`,
   paste **Prompt RW-ITEM** (§17) with the item number, build, playtest
   with the item's checklist, run **Prompt R**, then commit.
3. Commit messages start with the item tag, for example
   `[R1-05] Scav Snatcher and NPC Chase`.
4. If Claude Code hits something this file doesn't answer, use **Prompt G**
   (design gap) and bring it to the design project.

### For Claude Code
- Read this whole file before any R1 item. Then read only the `docs/`
  sections and `WORLD_MAP.md` sections the item lists.
- **Build order is the §14 status list, not the item numbers.** R1-08a
  and R1-08b come right after R1-01; R1-08c comes after R1-10.
- **R5 still rules everything:** the server decides every value, roll,
  drop, payout and theft. Clients send intents only. Odds never reach
  clients.
- **Reuse before you add.** Service and module names in this file are
  suggestions. If an existing service already owns the job (NodeService,
  VaultService, PlotService, the raid, Chase and Scav modules), extend it
  instead of creating a parallel one. Say which you chose in the summary.
- **Parking means switching off, never deleting.** Anything this file
  parks goes behind a `Config.Features` switch (§4).
- Keep the greybox contract (Hitbox + Visual, code never touches Visual)
  and the one-Config-for-every-number rule.
- Log any build-time call you make in **§18 Decision log** (one line:
  date, item, decision, reason). This replaces `design-changes.md` and
  D-numbers during the rework.
- Run **Prompt R** on every item that creates, moves, sells or deletes a
  gem, or pays Credits. Gem duplication is the number-one exploit risk.

---

## 1. Why the rework exists (read once)

Josh played the slice on his phone as a new player and found it boring.
The design project's diagnosis: the exciting parts (raids, Chases,
trading) all need other players, a new game starts with nearly empty
servers, and the solo-friendly fun (FTUE, crafting, goals) was scheduled
last. Mined ore also had almost nowhere to go.

The fix, in one sentence: **make every big moment work against NPCs
first, and let real players layer on top as servers fill.** Players now
protect and steal **gems**, visible things that earn money, instead of a
percentage of an Exposed pile.

---

## 2. Locked rework decisions

Josh chose these on 2026-09-24 (Appendix A of the Rework Plan).

| # | Decision | Choice |
|---|---|---|
| RW1 | What can be stolen | **Gems only.** Stone and Ore can never be stolen. |
| RW2 | Offline raiding | **Off at launch.** Players can only be raided while online. |
| RW3 | New-player shield | **First session:** the first 60 minutes [PH] of play time, replacing the 48-hour shield. |
| RW4 | Gem look | **Crystals** (simple faceted models). Creature gems are a later update. |
| RW5 | Breach Charges | **Crafted from Charge Parts (Scav drops) + Ore.** Riftsalt is parked. |
| RW6 | "Summon a Rich Vein" purchase | **Skipped.** No Robux products in R1 (the D107 scope wall still applies). |
| RW7 | Map layout | **The Quarry** (`WORLD_MAP.md`), reopened 2026-09-24. Replaces the 168-stud street. |
| RW8 | Design docs | **Frozen.** This file overrides them; decisions go in §18. |

Rework design rules (also locked for R1):

| # | Rule |
|---|---|
| RW9 | Gems on **pedestals** earn Credits per second and can be stolen (owner online only). Gems in the **vault** are safe and earn nothing. |
| RW10 | Nothing lost to an NPC is gone for good: it goes to the **Scav Camp**, where the owner can raid it back. |
| RW11 | A player whose hit ends a carrier's grip earns an **interceptor bounty** from the game (never from the victim), with anti-farming limits. |
| RW12 | Scav waves come **every 3–5 minutes** [PH] while online, starting inside the FTUE. |
| RW13 | Rewards are **loud**: every hit, gem and payout has sound, motion and a number. The Vaultborn *world beam* stays faint (it hides the location), but the finder's own reveal is loud. |

---

## 3. What this file overrides in `docs/`

| `docs/` section | Replaced by |
|---|---|
| `02 § FTUE spec` and `§ FTUE hard rules` (incl. rule 6, the 48-hour shield) | §13 FTUE v2 |
| `02 § Bank vs Exposed` (for Stone and Ore) | §5.6 Stone and Ore are safe |
| `02 § Bank vs Exposed § Special cases` (auto-bank) | §5.4 Prismatic and Vaultborn auto-vault |
| `02 § Raiding § Preconditions` (Riftsalt charges) | §9 Breach Charges |
| `02 § Theft math` | §7.1 one grab = one gem; offline raids off; transit sink parked |
| `02 § The Chase` point 5 | unchanged (grip, D115) **plus** §7.2 interceptor bounty |
| `04 § Scav Waves` (cadence, failure cost) | §6 NPC theft layer |
| D75 post-raid shield "starts at next login" | §8: starts immediately (no offline raids) |
| D110 Main Street layout, D113 street width, D110 plaza placement (derelict vault in the south plaza; plaza PvP on) | `WORLD_MAP.md`: The Quarry. Scav Camp at the Gate (§8); the Plaza is a truce square (§9) |
| Respawn location (docs silent) | `WORLD_MAP.md` §10: first join in the Plaza, later joins at your bridge mouth, every death respawns in the Plaza |
| Scav aggro on bystanders (docs silent) | `WORLD_MAP.md` §5: target lock |
| `05 § Grade` visuals "faint shimmer" for Dense | §10 juice: Dense and Volatile are obvious |
| Consistency decision #37 (a grab takes the best spare armor piece) | Off (`ArmorTheft = false`, RW1) |
| Captain Rare drop = 40 Research Scrap (temporary) | §5.2: one Dense gem + 2 Charge Parts |
| `03 § Level` (Reputation tracks, Level gates) | §12 simple Level, no gates |
| `10-roadmap § Build Order` steps 9–14, `13-build-guide § Part E` steps 9–14 | §14 R1 items |

Everything else in `docs/` still applies, especially R1–R8, combat, the
lockpick model, the Chase (grip D115, escape D114, escort D101), defenses,
plots and the greybox contract.

---

## 4. Feature switches

Add a `Features` table at the top of `Config.luau`. Every parked or new
system checks its switch on the server. Nothing parked is deleted.

```lua
Config.Features = {
    -- New in R1 (on)
    Gems = true,
    Pedestals = true,
    ScavSnatcher = true,
    ScavCamp = true,
    InterceptorBounty = true,
    CraftingBench = true,
    NpcBuyer = true,
    FirstSessionShield = true,
    RichVein = true,           -- §11
    SimpleLevel = true,        -- §12 (display + rewards only, gates nothing)
    TruceSquare = true,        -- WORLD_MAP §9 (no player damage in the Plaza)

    -- Parked (off). Code stays; behaviour switched off.
    OfflineRaids = false,      -- RW2
    ExposedOre = false,        -- RW1: Stone/Ore are safe, no Banked/Exposed split
    Riftsalt = false,          -- RW5
    ScavExposedTax = false,    -- old "failed wave takes 2% of Exposed"
    TransitSink = false,       -- old "20% destroyed in transit"
    DirectTrade = false,
    LevelGate = false,
    TechPath = false,
    ResearchBench = false,
    Crews = false,
    HarvesterDrone = false,
    NewAccountShield48h = false, -- replaced by FirstSessionShield
    ArmorTheft = false,        -- RW1: gems only (overrides consistency #37)
    ResearchScrap = false,     -- no Research Bench in R1
    Reaches = false,           -- §16: returns in R2; bridge barricaded (WORLD_MAP §8)

    -- R2 (off until built)
    InvitePrompts = false,
    DailyReward = false,
    GemIndex = false,
}
```

---

## 5. Gems (the thing players protect and steal)

### 5.1 What a gem is
A gem is a record in the owner's profile, created only by the server:

```
Gem = { id = <server GUID>, kind = "Quartz" | "Ember", grade = "Dense" |
        "Volatile" | "Prismatic" | "Vaultborn", foundAt = <server time> }
```

- **Kind** comes from the node type: Stone nodes give **Quartz**, Ore
  nodes give **Ember** [PH names; Josh's girlfriend can rename].
- **Grade** is the Grade of the hit that dropped it. There are no Standard
  gems.
- A gem exists in exactly one place at a time (§5.3). Moving a gem is one
  server function that removes it from the old place and adds it to the
  new one in the same step, then saves. **Never copy then delete.**

### 5.2 Where gems come from [PH]
Grade is still rolled per hit (build step 2). After the Grade roll, the
server rolls a gem drop:

| Hit Grade | Gem drop chance | Online income | NPC sell value |
|---|---|---|---|
| Standard | 0% | – | – |
| Dense | 12% | 1 Credit/s | 60 |
| Volatile | 40% | 4 Credits/s | 240 |
| Prismatic | 100% | 20 Credits/s | 1,200 |
| Vaultborn | 100% | 80 Credits/s | 4,800 |

- **Target:** an active new player finds a gem about every **60–90 s** of
  mining. If playtests say otherwise, tune `GemDropChance`, not the Grade
  odds.
- **First-session luck:** during a player's first 30 minutes [PH] of play
  time, gem drop chances are ×2 [PH]. Server-side only; odds stay hidden
  (D46; no Robux touches this).
- Other sources: the Scav Camp (§6.3), the Rich Vein (§11) and the Scav
  Captain: its Rare drop is now **one Dense gem + 2 Charge Parts** [PH],
  replacing the temporary 40 Research Scrap. The Signature drop (Captain's
  Cleaver skin) is unchanged.

### 5.3 The four places a gem can be

| Place | Earns | Stealable | Limit [PH] |
|---|---|---|---|
| **Pedestal** | Yes: online rate; offline rate per §5.5 | Yes, by players (owner online only) and by Scav Snatchers | Before a Vault Core: 1 (the free FTUE pedestal). Then by vault tier: tier 1 = 3, +1 per tier, max 9 |
| **Vault** | No | Never | Vault gem slots: tier 1 = 2, +1 per tier, max 8 |
| **Bag (loose)** | No | No | 3 loose gems |
| **Held by Scavs** | No | No (recover at the Scav Camp) | 5; beyond that the oldest is lost, with a clear message |

When a new gem arrives and the Bag is full: put it on an **empty
pedestal**; else in a **free vault slot**; else **sell it to the NPC
price** automatically and show a toast ("Bag full: sold Dense Quartz for
60"). The player can move gems between Bag, pedestal and vault any time
at their own plot.

### 5.4 Prismatic and Vaultborn
They go to a free vault slot automatically if one exists (replaces the old
auto-bank rule). Taking one out and **displaying** it is the player's
choice: the ultimate risky flex. If no vault slot is free, they follow §5.3.

### 5.5 Pedestal income
- Online: each displayed gem pays its rate every second, credited by the
  server in 1-second [PH] ticks. The pedestal shows a small `+N` popup to
  the owner on each payout and a glowing gem to everyone.
- **Offline ("while you were away"):** pays 10% [PH] of the online rate for
  the time away, **capped at 10 minutes' worth of full online income**
  [PH]. Computed from server timestamps on login, never client time.
  Show a payout screen on login. This keeps passive income slower than
  active play (R3).
- A gem that leaves the pedestal stops earning immediately.

### 5.6 Stone and Ore are safe
With `ExposedOre = false`: mined Stone and Ore go straight into the
player's safe totals, with no bank cap and no Exposed state. Hide the
Banked/Exposed meter. Spending works as before. With `ArmorTheft = false`, spare armor can't
be stolen either (RW1). The Bag's AT RISK column now shows only **gems on
pedestals**.

### 5.7 Profile changes
Add: `Gems` (map of id → gem), `GemPlaces` (pedestal slots, vault slots,
bag, scavHeld), `Credits` if not already present, `PlayTimeSeconds`,
`FirstSessionEndsAt` or equivalent, `LastLogout` (server time),
`ChargeParts`. Because nothing is public yet, **use a new ProfileStore
name** (for example `PlayerData_R1`) instead of migrating test profiles.

---

## 6. The NPC theft layer

### 6.1 Wave cadence [PH]
- The first wave is scripted inside the FTUE (§13).
- After the FTUE, a wave comes every **3–5 minutes** while the player is
  online and owns at least one pedestal (replaces "every 8–12 min, after a
  Vault Core").
- Keep the concurrent-wave ceiling (D59) and the Captain leading about 1
  wave in 4.
- With `ScavExposedTax = false`, a failed wave no longer takes 2% of
  Exposed. The wave's threat is the Snatcher.

### 6.2 The Scav Snatcher
Each wave includes **one Snatcher** [PH].
- **Target:** a random displayed gem on the player's plot. During the
  owner's first session it never targets Prismatic or Vaultborn [PH].
- **Grab:** stands at the pedestal for 2 s [PH], then carries the gem
  toward the Scav Burrow under the Spire at 14.5 studs/s [PH] (slower than
  a running player). Every plot is the same distance from the Burrow, so
  every run is ≈ 15 s (`WORLD_MAP.md` §5).
- **While carrying:** marked with the same carrier marker and trail as a
  player carrier, so everyone sees it.
- **HP 40** [PH], about one Wooden combo plus a hit. Any player can hit it.
- **Killed:** the gem goes straight back to its pedestal (or the vault if
  the pedestal is gone). If the owner lands the kill, they get a small
  **catch reward**: 15 Credits + XP (§12) [PH], so defending always feels
  good. Anyone else who kills it earns the interceptor bounty (§7.2).
  Waves come on a fixed schedule, so the catch reward can't be farmed.
- **Reaches the Burrow:** the gem moves to the owner's **Held by Scavs**
  list. Toast: "A Scav took your Dense Quartz to the Scav Camp. Raid it to
  get it back."
- If the pedestal holds nothing when the Snatcher arrives, it attacks
  defenses like a normal Scav.
- Where Scavs spawn (the Burrow only), which way they exit, who they
  ignore (target lock), the Captain entrance and the live-Scav cap:
  `WORLD_MAP.md` §5.

### 6.3 The Scav Camp
The FTUE's derelict vault **becomes the Scav Camp** and sits on the Gate
island in the north (`WORLD_MAP.md` §8); its exit faces the bowl. One camp
in R1; the second arrives with the Reaches in R2.
- **Entry:** the existing Skyrim-style lockpick, with wide sweet spots
  (easiest setting). **No Breach Charge, no band check.**
- **Guards:** 2 Scavs [PH] that respawn 60 s [PH] after dying.
- **Loot (instanced per player):** one grab gives **all your Held by Scavs
  gems** plus a reward roll [PH]: 50–150 Credits, 10–30 Ore, 1 Charge Part,
  and a 10% chance of a Dense gem.
- **Cooldown:** 8 minutes [PH] per player. Show a timer on the camp door.
- **Escape:** the player becomes a carrier (existing Chase rules: slowed,
  gadgets off, marked, grip 30). Escape radius **60 studs** [PH] from the
  camp centre, on solid ground. Guards chase.
- **Knocked loose or died:** recovered gems go back to Held by Scavs; the
  reward roll is lost. Other players can intercept and earn the bounty.

---

## 7. Player raids and the Chase

### 7.1 Theft is one gem
- **Preconditions:** 1 Breach Charge (§9), target within band (D66/D79/D92
  as built), target **online** (RW2), no shield (§8).
- The raid sequence, 90 s window, lockpick, escort, grip, escape radius and
  carrier death rules stay exactly as built.
- **Grab** = hold at one pedestal for 1.5 s [PH] to take **that one gem**.
  The raider chooses which pedestal. Vault gems can never be grabbed.
- **Escape:** the gem goes to the raider's Bag, then follows §5.3 if full.
- **Knocked loose / carrier died / timed out:** the gem returns to its
  pedestal (or the vault if the pedestal is gone).
- Loss is 1:1 in R1 (`TransitSink = false`).
- With `OfflineRaids = false`, offline bases still appear on free plots
  but can't be breached. Show "Owner offline: can't be raided" on
  approach.

### 7.2 Interceptor bounty [PH]
Paid by the game when a player's hit **ends a carrier's grip**: a player
carrier, a Snatcher, or a camp raider.
- **Amount:** 25% [PH] of the carried gem's NPC value (for camp loot, of
  the reward roll's Credits), minimum 25 Credits [PH].
- **Not paid to:** the gem's owner, the carrier's escort, the carrier's
  Roblox friends, anyone who already got a bounty from the same carrier in
  the last 30 minutes, or anyone past 5 bounties in the last hour.
- Announce it to the interceptor with a loud toast and sound ("Thief
  stopped! +60"). This makes crashing a Chase worth it for everyone.

---

## 8. New-player protection

- **First-session shield (RW3):** a new account can't be raided by players
  for its first **60 minutes of play time** [PH] (counted across sessions
  on the server). It ends early if the player starts a raid on a player
  base. Scav waves still happen (the FTUE depends on them).
- Show the shield on the HUD as a small icon with minutes left; no text
  before 2:30.
- The raid band (R6) stays.
- **Post-raid shield (D75):** 30 minutes [PH] after a successful theft
  from you, starting **immediately** (no offline raids to wait for).

---

## 9. Breach Charges and the Crafting Bench

### 9.1 Breach Charges (RW5)
- Scavs drop **Charge Parts**: 25% per Scav kill [PH]; the Captain drops 2;
  the camp reward roll gives 1.
- **Recipe:** Breach Charge = 2 Charge Parts + 15 Ore [PH].
- `Riftsalt = false`: no Riftsalt spawns, no Riftsalt recipe. Keep the
  existing `checkBreach` / `consumeBreach` hooks and point them at the new
  item.

### 9.2 Crafting Bench (replaces Workshop I for R1)
A **public station in the Plaza** (`WORLD_MAP.md` §9; no base
placement UX needed). Vertical, touch-friendly list; tap a recipe, see
cost, tap Craft. If a recipe already exists in `Config` from earlier
steps, keep its cost; otherwise use these [PH]:

| Recipe | Cost [PH] |
|---|---|
| Iron Pickaxe | 80 Ore + 40 Stone + 150 Credits |
| Iron Chest Armor | 60 Ore + 100 Credits |
| Lockpicks ×3 | 6 Ore |
| Shock Trap | 10 Ore + 20 Credits |
| Smoke Bomb | 8 Ore + 5 Stone |
| Sprint Serum | 10 Ore + 20 Credits |
| Breach Charge | 2 Charge Parts + 15 Ore |

Higher tiers (Voltsteel, Riftedge) stay out of R1.

### 9.3 NPC buyer
In the Plaza (`WORLD_MAP.md` §9). Buys:
- **Gems** at their NPC value (§5.2), no decay.
- **Stone** 1 Credit and **Ore** 3 Credits per unit [PH], with a simple
  per-player decay: −1% per unit sold today, floor 50%, reset at 00:00 UTC
  [PH] (a light version of D94).
Selling a gem asks for one confirmation if it's Volatile or better.

---

## 10. Juice pass v1 (client visuals only)

All of this is **client-side presentation triggered by server events**. It
never changes an outcome.

- **Every mining hit:** a material sound (Stone vs Ore), 3–6 particles, a
  small floating `+N`, and a **hit-stop of 0.06 s** [PH] (a brief freeze of
  the local swing animation only).
- **Node damage stages:** visible cracks at 66% and 33% [PH]; a burst of
  chunks when it breaks.
- **Grade on hit:** Dense = clear shimmer + chime; Volatile = crackle +
  small camera shake; Prismatic = rainbow flash + sting; Vaultborn = keep
  the faint world beam (it hides the spot) but give **the finder** a big
  personal reveal on their own screen.
- **Gem drop:** the gem pops out, spins once and flies to the player with a
  grade-coloured trail and a sound that gets bigger with Grade (about
  0.8 s [PH]).
- **Pedestal:** gem floats and glows; owner sees `+N` ticks; everyone sees
  the glow from the Rim and the Pit.
- **Chase:** carrier trail, a red screen-edge pulse for the carrier and the
  owner, the grip bar (D115), a loud "stopped!" moment when grip hits 0.
- **Payouts:** offline payout screen with a counting-up number.
- Put every look number in `Config` next to the existing
  `Config.Grade.FxLook` values.

---

## 11. The Rich Vein (the Pit's heartbeat)

The one event that pulls every player on the server into the same place at
the same time. A small, free version of the Riftfall idea. No Robux (RW6).

- **When:** every 4 minutes [PH] while at least one player is on the
  server. At most one vein at a time.
- **Where:** one of the 3 [PH] vein spots in the Pit (`WORLD_MAP.md` §7).
- **Warning:** a server banner through the D58 broadcast queue (below raid
  alerts and Chase pings, above cosmetic flex) and a visible glow at the
  spot, with a 10 s [PH] countdown.
- **The vein:** 5 [PH] special nodes with boosted Grade odds [PH]: Dense
  30%, Volatile 12%, Prismatic 2%, Vaultborn 0.2%, the rest Standard. Gem
  drop chances per Grade are the normal ones (§5.2), so more good hits
  means more gems. Odds stay server-side and hidden (D46).
- **Ends** after 60 s [PH] or when every node is mined out. Nodes don't
  respawn.
- **PvP:** normal Homestead rules. Fights and Chases here are the point.
- **FTUE hook:** when a new player reaches FTUE 8:00, if the next vein is
  more than 90 s away, bring it forward to 30 s [PH]. Allow this at most
  once every 3 minutes [PH] per server.
- **Analytics:** `RichVeinJoined` when a player lands at least one hit.

## 12. Simple Level (fast early progress)

Roblox's onboarding guidance is to level new players up quickly. This is a
single display Level: it **gates nothing** (`LevelGate = false`) and is
not the Reputation-track system from `03 § Level`.

- **XP** [PH]: mining hit 1 · gem found Dense 10, Volatile 25, Prismatic
  100, Vaultborn 300 · Snatcher caught 20 · camp raid escaped 30 · player
  raid escaped 50 · bounty earned 15 · Rich Vein node mined 3.
- **Curve** [PH]: XP to go from level L to L+1 = 40 + 30 × (L − 1).
  Targets: level 2 by about 1:30, level 5 by about 10 minutes, then
  roughly one level every 5–10 minutes.
- **Level-up:** a loud popup and sound, plus 25 × new level Credits [PH].
  The next goal is shown after each level-up ("Next: craft Iron Pickaxe",
  "Next: place a 3rd pedestal"...) from a short list in Config.
- **Shown** on the player's nameplate so others can see it.
- Profile: add `XP` and `Level` (derived from XP, like D80).

## 13. FTUE v2 [spec, second by second]

Replaces `02 § FTUE spec`. Times are targets [PH].

| Time | Player does | System does | Text |
|---|---|---|---|
| 0:00–0:10 | Taps a glowing node | Spawns facing it, pulsing arrow; loud hit feedback | None |
| 0:10–0:50 | Keeps mining | A **guaranteed Dense Quartz** drops by the 5th hit [PH] with the full reveal | None |
| 0:50–1:10 | Taps the glowing pedestal | A free pedestal is pre-placed on their plot; the gem goes on it; `+1` ticks start; **free pickaxe skin granted** | Button label only |
| 1:10–2:30 | Chases a Scav Snatcher | A scripted Snatcher grabs the gem and runs slowly (6 studs/s, 20 HP [PH]); the player always catches it; gem returns | None |
| 2:30–4:00 | Places the Vault Core | Big "BUILD VAULT" button; vault slots appear | **One line:** "Gems on pedestals earn, but can be stolen. Your vault keeps them safe." |
| 4:00–6:00 | Raids the Scav Camp | Guided, extra-wide lockpick; guards passive; guaranteed Dense Ember; short escape | Minimal prompt |
| 6:00–8:00 | Crafts the Iron Pickaxe at the Crafting Bench | If the player is short on Ore, Stone or Credits, the FTUE tops up the difference once [PH]; big upgrade moment. By now they've levelled up at least twice (§12) and see a next goal | Button labels |
| 8:00–10:00 | Races to the Rich Vein | The next vein is pulled forward if needed (§11); server banner; free play begins | Banner |

**Hard rules v2:**
1. No text before 2:30 (button labels only).
2. First reward by 0:60 (the first gem), plus the free skin at the pedestal.
3. PvE before PvP: the player catches a thief before anyone can rob them.
4. Their first steal is a win (the Scav Camp).
5. Nothing parked by §4 is visible. No trading, tech tree, ranks, crews.
6. The first-session shield (§8) replaces the 48-hour shield.

A returning player who quit mid-FTUE resumes at the step they reached.

**Positions:** the first-session spawn is in the Plaza facing the bowl,
and the first glowing node is on the Rim just outside the Plaza bridge
(`WORLD_MAP.md` §6, §10). An FTUE player always gets one of plot fill
slots 1–4, so every FTUE walk is ≤ ~16 s. The 4:00–6:00 camp raid is at
the Gate. Banners use the place names in `WORLD_MAP.md` §1.

---

## 14. The R1 items (in order)

Sizes use the estimate's key: S ≈ 1 session, M ≈ 2–3, L ≈ 4–6.
After every item: Prompt R, then commit. **Build in the order of the
status list below**; item numbers are labels, not the order. Each item names its model and
effort; §14.1 explains how to set them.

### 14.1 Model and effort

**How to set them in Claude Code:** `/model` picks the model (use the
left/right arrows there to adjust effort), or `/effort high` sets effort
directly. `/effort auto` goes back to the model's default. Opus 5.5
starts at **medium** unless you change it, and most other models start at
high, so always set effort explicitly for Opus items.

**The pattern:** build exploit-sensitive items with **Opus 5.5 at high**;
build everything else with **Sonnet 5**, at **medium** for small or
mechanical items and **high** for larger ones. Review anything that moves
gems or Credits with **Opus at high**, even when Sonnet built it.

**If an item goes wrong:**
1. First, describe the bug with Prompt B at the same settings.
2. Still stuck after two tries: raise effort one step (medium → high →
   xhigh).
3. Still stuck at high or xhigh: switch Sonnet → Opus, starting again at
   high.
4. Don't leave effort on max. It costs the most tokens and tends to
   overthink; drop back to the recommended level for the next item.

**Why not always Opus at max?** It spends many more credits and can
overthink simple jobs (doing more than you asked). The model's default
level is tuned so most tasks finish without overspending.

**Other prompts:** Prompt RW-START: Opus · medium (reading and mapping,
no code). Prompt B (bugs): the item's own settings. Prompt G (design
gap): Opus · medium. Commit: Sonnet · low.

### Status (tick when committed; Vault Ops reads these lines)
- [ ] R1-00 Movement trust (M1) · Opus high
- [ ] R1-01 Branch, switches, pointer · Sonnet medium
- [ ] R1-08a Quarry geometry (right after R1-01) · Sonnet high
- [ ] R1-08b Plot fill order, spawns and respawns · Opus high
- [ ] R1-02 Gem data and drops · Opus high
- [ ] R1-03 Pedestals, vault gem slots, income · Opus high
- [ ] R1-04 Theft targets gems; offline raids off · Opus high
- [ ] R1-05 Scav Snatcher, NPC Chase, Scav Camp · Sonnet high
- [ ] R1-06 Wave cadence and FTUE hook · Sonnet medium
- [ ] R1-07 Interceptor bounty · Opus high
- [ ] R1-09 Crafting Bench · Sonnet high
- [ ] R1-10 NPC buyer · Sonnet high
- [ ] R1-08c Map dressing and legibility · Sonnet high
- [ ] R1-11 Juice pass v1 + cheap-phone check · Sonnet high
- [ ] R1-12 Analytics events · Sonnet medium
- [ ] R1-12a Simple Level · Sonnet medium
- [ ] R1-12b Rich Vein · Sonnet high
- [ ] R1-13 FTUE v2 · Opus high
- [ ] R1-14 Protection, truce square and charges cleanup · Opus high
- [ ] R1-15 Private playtest and fixes · Sonnet high
- [ ] ~~R1-08 Street width 168~~ · superseded by R1-08a (v1.2 item; don't build)

### R1-00 — Movement trust (backlog M1) · M
- **Model / effort:** Opus 5.5 · high (exploit-critical: every later gem and Chase check trusts it). **Prompt R:** Opus high.
**Skip if already done** (check `backlog.md`; say so and move on).
- Server-side movement check: max speed with tolerance, teleport
  detection, and a `isPositionTrusted(player)` answer other services ask.
- Use it in: mining, pedestal actions, grabs, camp grabs, escape checks,
  bounty hits.
- **Done when:** a speed or teleport exploit (simulate by moving the
  character on the client) can't mine, grab or escape; normal play,
  knockback and respawn never trip it.

### R1-01 — Branch, switches, pointer · S
- **Model / effort:** Sonnet 5 · medium (setup and switches; little reasoning). **Prompt R:** Sonnet high.
- Tag the current commit `slice-step8`, create branch `rework`.
- Add `Config.Features` (§4) and wire each parked system to its switch.
- Add the §17 pointer text to the top of `CLAUDE.md`.
- **Done when:** the game runs with every parked switch off and nothing
  parked is visible; flipping a switch back on restores the old behaviour.

### R1-08a — Quarry geometry · M (build right after R1-01)
- **Model / effort:** Sonnet 5 · high (a full regeneration of the world script). **Prompt R:** Opus high.
- `WORLD_MAP.md` §1–§4, §5 (Spire and Burrow geometry only), §6, §7, §8,
  §9.2 (Plaza shape and station slots only), §15 (scenery greybox shapes
  only), §19 tags, §21.1 checks 1–5, 7, 8.
- Regenerate `docs-build/worldgen/gen_world.py` from the `WORLD_MAP.md` §3
  table. **This is a new layout, not a width change.** Keep every greybox
  contract (Plot tag, PlotIndex, Hitbox, Bridge<index>, Scav ground ~60
  studs toward the bridge). Every number goes in `Config.World` with
  `-- WORLD_MAP §N [PH]`. Barricade the Reaches bridge
  (`Features.Reaches = false`).
- Add `validate_world.py` (or a `--check` mode in `gen_world.py`) that runs
  the §21.1 checks and fails loudly.
- **Done when:** the validation passes; all 8 bridges and plot-to-centre
  distances match within 1 stud; every gate faces the centre and the build
  grid follows; plot → centre ≈ 13.5 s and Plaza spawn → fill slots 1–4
  ≤ ~16 s on foot; D111's 140-stud escape still triggers on every plot;
  Scavs can path from the Burrow to every plot's Scav ground; nothing
  clips or floats.

### R1-08b — Plot fill order, spawns and respawns · S (right after R1-08a)
- **Model / effort:** Opus 5.5 · high (respawn location protects D3; plot and friend assignment are easy to get subtly wrong). **Prompt R:** Opus high.
- `WORLD_MAP.md` §10: fill order, friend placement, offline display bases
  yield their plot, FTUE players get fill slots 1–4, first-session and
  later-join spawns, every death respawns in the Plaza, home beacon
  (client-only). Carrier death still returns the loot (D111).
- **Done when:** two fresh test clients land on fill slots 1 and 2; a
  friend joins next to their friend; an offline display base moves when an
  online player needs the plot; jumping off the Rim respawns you in the
  Plaza, never at home; a returning player spawns at their own bridge
  mouth; the home beacon shows only for its owner.

### R1-02 — Gem data and drops · M
- **Model / effort:** Opus 5.5 · high (gem records and the one move function; duplication risk). **Prompt R:** Opus high ×2.
- §5.1, §5.2, §5.7. New ProfileStore name. Gem drops on hits, first-session
  luck, Bag with the §5.3 overflow flow (pedestal and vault steps can stub
  until R1-03).
- Bag gets a **Gems** tab.
- **Done when:** mining produces gems at roughly the target rate; gems
  survive rejoin; two fast clients and a rejoin mid-drop never duplicate
  or lose a gem; no gem data or odds reach the client beyond what's
  displayed.

### R1-03 — Pedestals, vault gem slots, income · M
- **Model / effort:** Opus 5.5 · high (money over time, offline payout from server timestamps). **Prompt R:** Opus high ×2.
- §5.3–§5.6. Pedestal is a buildable piece (cost 30 Stone + 10 Ore [PH],
  counts against the build budget). Vault gem slots by tier. Online ticks,
  offline payout, Prismatic/Vaultborn auto-vault.
- `ExposedOre = false` behaviour (§5.6); hide the Banked/Exposed meter.
- **Done when:** gems move freely between Bag, pedestal and vault;
  income ticks only for displayed gems; logging out for 20 minutes pays
  the capped offline amount once; changing the device clock changes
  nothing.

### R1-04 — Theft targets gems; offline raids off · M
- **Model / effort:** Opus 5.5 · high (theft, Chase and disconnect edge cases). **Prompt R:** Opus high ×2.
- §7.1. Grab one gem from a chosen pedestal; escape → raider's Bag;
  fail → back to the pedestal. `OfflineRaids = false`,
  `TransitSink = false`.
- **Done when:** a two-client test can steal exactly one displayed gem,
  never a vaulted one; an offline base can't be breached; leaving
  mid-Chase, dying, or both players disconnecting never duplicates or
  deletes the gem.

### R1-05 — Scav Snatcher, NPC Chase, Scav Camp · L
- **Model / effort:** Sonnet 5 · high (large but built on R1-02's gem move function; Opus reviews it). **Prompt R:** Opus high.
- §6.2, §6.3. The derelict vault becomes the Scav Camp (reuse the
  lockpick and carrier code). Held by Scavs list, camp loot, cooldown.
- `WORLD_MAP.md` §5 and §8: Snatchers run to the Burrow; Burrow is the
  only Scav spawn; emergence toward the target, 0.5 s apart; target lock;
  Captain entrance; live-Scav cap; camp exit faces the bowl; camp door
  light.
- **Done when:** a Snatcher can take a gem and be caught (gem returns);
  a Snatcher that reaches the Burrow moves the gem to Held by Scavs; a
  Snatcher run takes about the same time from every plot; Scavs ignore a
  bystander who doesn't hit them; raiding
  the camp returns every held gem plus the reward; cooldown works; other
  players can intercept.

### R1-06 — Wave cadence and FTUE hook · S
- **Model / effort:** Sonnet 5 · medium (timers and a hook). **Prompt R:** Sonnet high.
- §6.1. Waves every 3–5 min [PH] once a pedestal exists; a function the
  FTUE can call to start the scripted Snatcher. Waves spawn only from the
  Burrow; the live-Scav cap (~24 [PH], `WORLD_MAP.md` §5) holds alongside
  D59.
- **Done when:** waves arrive on schedule; `ScavExposedTax = false` takes
  nothing; the concurrent-wave ceiling still holds with 8 players.

### R1-07 — Interceptor bounty · S
- **Model / effort:** Opus 5.5 · high (anti-farming rules are easy to get subtly wrong). **Prompt R:** Opus high ×2.
- §7.2, including every "not paid to" rule.
- **Done when:** a third player stopping a carrier gets paid; the owner,
  escort and friends don't; the hourly cap and 30-minute repeat rule
  hold; a two-account farming loop earns almost nothing.

### R1-09 — Crafting Bench · M
- **Model / effort:** Sonnet 5 · high (UI plus server-checked costs). **Prompt R:** Sonnet high.
- §9.1, §9.2. Plaza station, recipes, Breach Charge recipe, Charge Parts
  drops from Scavs and the Captain.
- **Done when:** every recipe crafts with correct costs, server-checked;
  a player can go from zero to a Breach Charge by fighting Scavs.

### R1-10 — NPC buyer · S
- **Model / effort:** Sonnet 5 · high (sells gems for Credits; Opus reviews it). **Prompt R:** Opus high.
- §9.3.
- **Done when:** gems sell at their value; Stone and Ore decay per unit
  and reset at 00:00 UTC; selling can't be spammed or duplicated.

### R1-08c — Map dressing and legibility · M (after R1-10, before R1-11)
- **Model / effort:** Sonnet 5 · high (many props plus safety rules). **Prompt R:** Sonnet high.
- `WORLD_MAP.md` §11 (legibility), §12 (colour key), §13 and §14 **R1 tier
  only** (skip "R1 if time" unless Josh asks), §15 (cliffs, vault door,
  cloud deck as greybox), §18 streaming settings, §19 reserved slot tags,
  §21.1 check 6. Client-only visuals from existing server state; no new
  systems.
- **Done when:** all §21.1 checks pass; the colour key touches `Visual`
  only; streaming is on with the recommended settings; banners flash
  during a raid; offline lanterns dim; nothing standable sits above 3
  studs within 40 studs of a plot.

### R1-11 — Juice pass v1 + cheap-phone check · M
- **Model / effort:** Sonnet 5 · high (lots of client polish; no outcomes change). **Prompt R:** Sonnet high.
- §10, plus `WORLD_MAP.md` §13 ambience, §16 event looks and §17
  lighting. Then run the cheap-phone test still open from build step 0B:
  an inexpensive Android phone, **standing in the Pit** with all 8 plots
  loaded, a vein, a Scav wave and a Chase on screen at once. Pick Future or
  ShadowMap lighting by this test.
- **Done when:** on a phone, mining feels satisfying for five minutes
  straight (Josh's judgement); no juice code changes an outcome; the cheap
  phone holds a playable frame rate (target 30 FPS [PH]). If it doesn't,
  cut in the `WORLD_MAP.md` §14 order (skyline, then "R1 if time"
  dressing, then particles), never the Chase feedback, compass mosaic,
  rails, milestones or banners.

### R1-12 — Analytics events · S
- **Model / effort:** Sonnet 5 · medium (event calls in known places). **Prompt R:** Sonnet high.
- §15. Onboarding funnel, custom events, economy events. Confirm the exact
  AnalyticsService function names on the Creator Hub before using them.
- Remind Josh to create an Open Cloud API key with the
  `universe.analytics:read` permission for Vault Ops (module O4). Never
  put the key in the repo.
- **Done when:** events show in the Creator Dashboard after a published
  private test.

### R1-12a — Simple Level · S
- **Model / effort:** Sonnet 5 · medium (small, server-only XP). **Prompt R:** Sonnet high.
- §12.
- **Done when:** a new player reaches level 2 in about 90 s and level 5
  in about 10 minutes of normal play; XP is server-only; level-ups pay
  once and survive rejoin; the next-goal line updates.

### R1-12b — Rich Vein · M
- **Model / effort:** Sonnet 5 · high (reuses nodes and the broadcast queue; performance matters). **Prompt R:** Sonnet high.
- §11. Reuse the node system and the D58 broadcast queue. Spot positions
  and looks: `WORLD_MAP.md` §7, §16.
- **Done when:** veins appear on schedule at the marked spots with a
  countdown; boosted odds apply only to vein nodes; the FTUE pull-forward
  works and respects its limit; 8 players on one vein don't drop the
  frame rate on the cheap phone.

### R1-13 — FTUE v2 · L
- **Model / effort:** Opus 5.5 · high (many systems, second-by-second spec, resume logic). **Prompt R:** Opus high.
- §13, second by second, with the funnel steps from §15. Spawn and
  first-node positions: `WORLD_MAP.md` §6, §10.
- **Done when:** a fresh account reaches free play in about 10 minutes
  with no help; no text before 2:30; nothing parked is visible; quitting
  and rejoining mid-FTUE resumes correctly. **Watch someone who has never
  seen the game play it without helping them.**

### R1-14 — Protection, truce square and charges cleanup · M
- **Model / effort:** Opus 5.5 · high (shield and band rules (R6)). **Prompt R:** Opus high.
- §8 first-session shield and immediate post-raid shield;
  `NewAccountShield48h = false`; confirm `Riftsalt = false` everywhere.
- `WORLD_MAP.md` §9.1 truce square: no player damage or knockback in the
  Plaza except on carriers (grip still drains); no hit-and-hop (5 s
  [PH]); server-side position check via R1-00.
- **Done when:** a new account can't be raided for 60 minutes of play
  time, the shield survives rejoin, ends when they raid, and the band
  still blocks out-of-band targets; two clients can't damage each other
  in the Plaza; a carrier can still be knocked loose there; hitting
  someone then stepping in gives no protection for 5 s.

### R1-15 — Private playtest and fixes · M
- **Model / effort:** Sonnet 5 · high (per bug; switch to Opus high for anything touching gems, raids or Credits). **Prompt R:** Sonnet high.
- Publish privately. Run the playtest kit (Rework Plan, Appendix C) with
  5–10 players on phones. Fix the top three problems found.
- Before anyone outside Josh's circle plays: M1 done (R1-00) and the
  cheap-phone check passed (R1-11). Both are launch blockers.
- **Done when:** Josh has the observation sheets and the top three fixes
  are committed.

---

## 15. Analytics events (for R1-12 and R1-13)

**Onboarding funnel** (one step each, in order): `FirstHit`, `FirstGem`,
`FirstPedestal`, `FirstIncomeTick`, `SnatcherCaught`, `VaultPlaced`,
`CampRaidStarted`, `CampRaidEscaped`, `IronPickaxeCrafted`, `RichVeinReached`,
`FreePlay`.

**Custom events** (names [PH], keep them short and stable):
- `GemFound` (grade, kind) · `GemPlaced` · `GemVaulted` · `GemSold` (grade)
- `SecondPedestalPlaced` (once per player)
- `GemStolen` (by = player | scav) · `GemRecovered` (source = chase | camp)
- `RaidStarted` · `RaidEnded` (result = escaped | knocked | died | timeout)
- `ChaseEnded` (carrier = player | snatcher | camp; result)
- `BountyPaid` (amount)
- `QuitAfterGemLoss` (logged at session end if the player lost a gem in
  the last 5 minutes)
- `OfflinePayout` (amount)
- `LevelUp` (level) · `RichVeinJoined`

**Economy events:** Credits in (pedestal, offline, NPC sale, bounty, camp,
catch reward, level-up) and out (crafting, building).

Vault Ops (the local reporting tool) reads these through the Open Cloud
Analytics Query API, so keep names stable once published.

---

## 16. Not in R1

**At public launch (first R2 item):** the D107 scope wall on Robux lifts.
Add a small cosmetic shop (pickaxe skins, trails, pedestal skins; fixed
items only, nothing random) and a cheap VIP server. An extra-vault-slots
pass can follow (safety capacity, allowed by R3). Any Robux path to a
random outcome needs published odds and PolicyService gating (Roblox's
paid random items policy), so avoid them.

**Shop rules (one booth, `WORLD_MAP.md` §9):** fixed-price cosmetics only;
preview on your own avatar before buying; the weekly featured set and the
VIP server live inside the shop's one menu; honest end dates that never
reset; no purchase prompts in a player's first 10 minutes; no spending
leaderboards or donation boards; no gifting to non-friends; nothing random
behind Robux (PolicyService required if that ever changes). Every cosmetic
category also has free earnable items (streak day 7, gem index,
referrals).

**R2 (weekly updates after publishing, one per week):** a second Scav Camp;
invite prompts and referral rewards; daily reward; rotating trader stock;
gem index and base skins; hide-UI creator camera; Resonance nodes (D102);
the Reaches return; Vault Rush weekly event; optional raid alarm. Map
R2 candidates: `WORLD_MAP.md` §20. More ideas: Rework Plan Part 13.

**Parked (switches off):** offline raids, Exposed ore, Riftsalt, transit
sink, direct trade, Level gate, Tech Path, Research Bench, blueprints,
crews, Harvester Drone, all Robux products (D107 scope wall).

---

## 17. Prompts

### Prompt RW-START (once)
```
Read CLAUDE.md, then REWORK.md in full. Don't write features yet.
1. Tell me whether backlog item M1 (movement trust) is done, with the
   file where it lives. If not, R1-00 comes first.
2. Tag the current commit slice-step8 and create a branch called rework.
3. Add this to the very top of CLAUDE.md:
   "REWORK PHASE R1 IS ACTIVE. Read REWORK.md before any work. Where
   REWORK.md and docs/ disagree, REWORK.md wins. For the map, WORLD_MAP.md
   is the spec. docs/ is frozen: do not edit it. Log build-time calls in
   REWORK.md §18, one line each."
4. List which existing services and modules you'll extend for each R1
   item (NodeService, VaultService, PlotService, raid, Chase, Scav...),
   and anything in REWORK.md that conflicts with the current code.
5. Tell me the first R1 item to do (R1-00 if M1 isn't done, otherwise
   R1-01) and the model and effort REWORK.md §14 gives it, so I can switch
   with /model or /effort before pasting the next prompt.
Show me the list and wait.
```

### Prompt RW-ITEM (every item)
```
Read REWORK.md § 14 item R1-XX and every section it points to
(including WORLD_MAP.md sections), plus the docs/ sections those
mention. Goal: <one sentence from the item>.
Keep R5 (server authority) and the greybox contract. Put every new
number in Config.luau with "-- REWORK §N [PH]" (or "-- WORLD_MAP §N
[PH]" for map numbers). Respect
Config.Features. Don't change systems outside this item.
Plan first and show me the plan. After I say go, build it.
When done: list files changed, new Config values, anything you logged
in REWORK.md §18, and the item's "Done when" checklist as steps I can
test in Studio.
Last, look at the status list in REWORK.md §14 and tell me: (1) the
model and effort for this item's Prompt R review, and (2) the next
unchecked item with its model and effort, so I can switch before I
/clear and paste the next prompt.
```

### Vault Ops prompts (separate folder, Rework Plan Appendix D)
| Prompt | Model · effort |
|---|---|
| O0 Core | Sonnet · medium |
| O1 Tracker | Sonnet · high (live API details, rate-limit handling) |
| O2 Sweep | Sonnet · medium |
| O3 + O5 Notes | Sonnet · medium |
| O4 My game | Sonnet · high (Open Cloud API, polling) |
| O6 Build and decisions | Sonnet · low |
| O7 Weekly report | Sonnet · high (rules, charts, decision gate) |
| O8 Claude pack | Sonnet · medium |
| O9 Full schedule | Sonnet · medium |

### Also use
- **Prompt R** (review) after every item, twice for R1-02, R1-03, R1-04,
  R1-07.
- **Upgrading from v1.2:** the one-time prompt is in
  `HANDOFF_REWORK3.md`. Delete that file after the handoff commit.
- **Prompt B** (bug report) and **Prompt G** (design gap) as before.
- **Commit:** `[R1-XX] <summary>`, then push.

---

## 18. Decision log

One line per build-time call: `date · item · decision · reason`.

- 2026-09-24 · — · RW1–RW13 locked from the Rework Plan v1.1 · Josh's choices.
- 2026-09-24 · — · REWORK.md v1.1: Rich Vein and a simple Level moved into R1
  (R1-12a/12b); cheap-phone check added to R1-11; armor theft and Research
  Scrap switched off; Captain Rare drop changed; owner catch reward added;
  status checkboxes added · to match the Rework Plan's FTUE and its "five
  changes that matter most".
- 2026-09-24 · — · REWORK.md v1.2: model and effort for every item and prompt
  (§14.1); RW-START and RW-ITEM now end with the next step's model and
  effort · Josh wants a recommendation before each step.
- 2026-09-24 · RW-START · Tag is `slice-step9` at HEAD (not `slice-step8`) · HEAD already contains Step 9.
- 2026-09-24 · RW-START · Commit the uncommitted UI rework on main before tagging and branching · so the tag includes it and nothing mixes into R1-01.
- 2026-09-24 · R1-02/05 · §5.3 Held by Scavs overflow: the oldest held gem is auto-sold to its owner at NPC value with a toast, not lost · RW10 and R2 (nothing destroyed below vault tier 8).
- 2026-09-24 · R1-01 · Step 9 direct trade, old Level/Reputation UI are switched off behind Config.Features, never deleted; NpcShop is extended in R1-10 · "parking means switching off".
- 2026-09-24 · — · REWORK.md v1.3 + WORLD_MAP.md v1.0 · Main Street played like a runway; the Quarry keeps every mechanic and timing.
- 2026-09-24 · R1-08a · D110 and RW7 reopened: The Quarry replaces Main Street (WORLD_MAP §3). Plot ring r 216, bridges 32, Rim road r 136–160, Pit r 112 · research favours centre-focused maps; equal bridges and rim-high plots fix both old ring rejections (unequal bridges, drop-ins).
- 2026-09-24 · R1-05/R1-14 · D110 plaza placement reopened: Scav Camp to the Gate island (exit faces the bowl); Plaza is a truce square with no hit-and-hop · safe-south/danger-north gradient; no griefing at the buyer and bench.
- 2026-09-24 · R1-05/R1-06 · The Burrow under the Spire is the only Scav spawn; Snatchers run to it at 14.5 studs/s (≈ 15 s from every plot); emerge toward target 0.5 s apart; target lock (ignore bystanders unless hit/defending); Captain entrance; live-Scav cap ~24 · fairness, readability, NPC clump lag, no Charge Part farm; docs were silent on bystander aggro.
- 2026-09-24 · R1-08b · Fill order nearest the Plaza first; friends placed together; FTUE players get slots 1–4; later joins spawn at own bridge mouth; every death respawns in the Plaza; home beacon; no teleport buttons · death-teleport home would have broken D3.
- 2026-09-24 · R1-08c/R1-11 · Map dressing and ambience in R1 / "R1 if time" tiers (WORLD_MAP §11–§16), greybox colour key, decor safety rule (nothing standable above 3 studs within 40 of a plot), scenery ≥ 30 studs from walkable, streaming + LOD, fixed lighting, place names · more to see with no mechanic changes; cheap-phone gate protected by a cut order.
- 2026-09-24 · R1-08a/R1-09/R1-10 · Plaza 120 × 88, 6 stations max (arch + spawn, overlooks, buyer, brazier seats, bench; shop, event pad, board tagged for later); §16 shop rules · research: Brainrot, Grow a Garden and 99 Nights run 3–6 hub stations and rotate event machines.
- 2026-09-24 · R1-01 · Features.Reaches = false and Features.TruceSquare = true · §16 parked the Reaches without a switch; the truce square needs one.
- 2026-09-24 · §14 · R1-08 split into R1-08a (geometry), R1-08b (plots and spawns), R1-08c (dressing); 08a/08b build right after R1-01 · R1-05, R1-12b and R1-13 depend on the map.
- 2026-09-24 · — · Map layout locked for R1; new map additions wait for R1-15 playtest data.

---

## 19. Map layout: The Quarry

The map spec lives in **`WORLD_MAP.md`** (repo root), with a to-scale
reference drawing in `docs-build/worldgen/WORLD_MAP.svg`. It replaces
D110 (Main Street) and RW7 (168-stud street).

In short: 8 plot islands on the **Rim** of a round quarry, each on an
identical 32-stud bridge to a railed Rim road; a gentle slope into the
**Pit**, where the Rich Veins erupt; the crystal **Spire** at the centre,
standing over the **Burrow**, the only Scav spawn; the Scav Camp on the
**Gate** island in the north, in front of a giant vault door; and the
**Plaza** in the south, a truce square with 6 stations at most and the
first spawn.

Built by R1-08a (geometry), R1-08b (plot order and spawns) and R1-08c
(dressing), with pieces in R1-05, R1-06, R1-11, R1-12b, R1-13 and R1-14.

**The layout is locked for R1.** New map additions wait for R1-15
playtest data. `WORLD_MAP.md` wins on positions, shapes, spawns and
dressing; this file wins on system rules and system numbers. If they seem
to disagree, stop and use Prompt G.
