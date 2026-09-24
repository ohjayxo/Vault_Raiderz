# Design changes made during the build

These were applied directly to `docs/` (v5.7, 2026-09-20, with Josh's double
confirmation). **The separate design project still has the old text**: make
the same changes there before the next copy-in, or it will overwrite them.

## v5.7 (2026-09-20)

1. **D111: pickaxes are not tradeable; pickaxe skins are** (supersedes D21).
   Changed: `07-decisions.md` (new D111, D21 marked superseded, D65/D66/R3/
   rejected-options table reworded), `05-items.md` (Taxonomy row, governing
   split, § Gear is tradeable → § Pickaxes are not tradeable, § Loss rules),
   `06-economy.md` (Fragments-only tradeable paragraph).
2. **D92 wording fix:** gear score counts pickaxe upgrade nodes (Extraction /
   Combat / Mobility), not Tech Path nodes. Changed: `07-decisions.md § D92`,
   `05-items.md § Gear score`.
3. **Level curve [PH]:** XP to reach track level n = floor(100 × n^1.5);
   Vaultbreaker Level = sum of track levels; Level derived from XP, not stored.
   Changed: `03-progression.md § Vaultbreaker Level`, `07-decisions.md § D80`
   (build note).
4. Housekeeping: `10-roadmap.md` v5.7 history row; `12-nexus.md` registry
   D1–D111, next D112; `CLAUDE.md` docs-edit rule (double confirmation).

5. Follow-ups (confirmed separately): `08-questions.md` Q17 answer now "No
   (D111)"; `00-README.md` bumped to v5.7; `12-nexus.md` v1.7 history row.
6. **D112: armor in the slice.** Craftable pieces, one chest slot, pickaxe tier
   names, knockback resistance + small damage reduction [PH], spares stealable
   / worn never (R1), not tradeable (armor skins are), gear score + highest owned
   armor tier × 10. Changed: `07-decisions.md` (new D112, D92), `05-items.md`
   (Taxonomy row, new § Armor, § Gear score), `10-roadmap.md` (slice table row,
   v5.7 row), `12-nexus.md` (registry D1–D112, next D113; v1.8 row).

## Step 2 design-gap answers (2026-09-20) — NOT yet in `docs/`

Josh's calls while building nodes + Grade. Bring them to the design project;
`docs/` is unchanged until he double-confirms an edit.

1. **Grade is rolled per hit**, not per node (`05-items.md § Why Grade
   carries so much` "every tap is a lottery ticket" vs `§ The Voltstone
   trickle` "a Volatile-grade Ore node"). Suggest rewording the Voltstone
   line to "a Volatile-grade Ore hit".
2. **Grade effects are seen by everyone**, as a short burst at the node
   (Prismatic rainbow column, Vaultborn beam). The 30 s head start still
   holds because the holder walks away. (`05-items.md § Roll 1` Visual column.)
3. **Vaultborn ranks in the middle of the D58 queue**: below raid-owner
   alerts and Chase pings, above cosmetic flex (`06-economy.md § Broadcast
   priority queue`).
4. **Head start interpretation:** the Vaultborn announcement goes out ~30 s
   [PH] after the strike (`05-items.md § Vaultborn announcement`).
5. **Node migration interpretation (D38):** a depleted Reaches node returns
   after a random 45–90 s [PH] at a *different* spawn point; Homestead nodes
   return at the same spot after a fixed 30 s [PH].

## Step 3 design-gap answers (2026-09-20) — APPLIED to `docs/` 2026-09-21

Josh's calls while building Bank/Exposed. Applied with double confirmation:
`02-core-loop.md § Bank vs Exposed` (table reworded + banking paragraph) and
`00-README.md` glossary (Exposed). **Still owed to the design project.**

1. **Banking is manual, at the Vault Core.** Everything mined lands in
   Exposed; the player uses their Vault Core ("Bank") to move it in until the
   cap is full. Only Prismatic/Vaultborn skip this (§ Special cases). This is
   what makes "one more run, or bank now?" a real choice.
2. **Capacity counts total units** of all resources and Grades combined
   (not per resource, not by value). Research Scrap keeps its own cap
   (20% [PH] of this).
3. **Bank order when it doesn't all fit: best first.** Highest Grade first
   (Vaultborn → Standard), then rarer resource (Riftsalt → Ore → Stone).

## Step 4 design-gap answers (2026-09-21) — NOT yet in `docs/`

1. **Band metric scales (D66 / D79 / D92):** gear score is converted to tier
   units, floor(gear score / 10), before taking the highest of vault tier,
   lifetime peak and gear score. Raw, gear score (a Wooden pickaxe alone = 10)
   would always win. Suggest adding this to `02-core-loop.md § Preconditions`
   or D66.
2. **Removing a base piece refunds 50% [PH]** (as Standard, into Exposed).
   A full refund would let players hide resources from raiders inside walls.
   The Vault Core can be moved but never removed (tier and bank never drop,
   R2). Suggest a line in `02-core-loop.md § Base / Home`.
3. **Spending takes Exposed before Banked, lowest Grade first.** Suggest a
   line in `02-core-loop.md § Bank vs Exposed`.
4. **Placing the Vault Core = vault tier 1; tiers 2–7 are bought with an
   "Upgrade Vault" action** (costs [PH]). Interpretation of § Base / Home
   ("Tier 1 wooden shack → Tier 10").
5. **Owner walks through their own gates**; everyone else is blocked until
   step 7 breaching. Interpretation of § Buildable elements.
6. **Step 4 built before the cheap-phone test** (Josh accepted). Step 0B
   finding for the design project: **D57's "piece count" is the wrong budget
   unit.** Identical pieces batch almost free; triangles and unique materials
   cost frame time (`docs-build/perfspike/results.md`). The build counts a
   per-piece `BudgetCost` meant as render weight. Suggest rewording D57 to
   "render-weight budget (triangles + unique materials)".

## Step 5 design-gap answers (2026-09-21) — NOT yet in `docs/`

1. **Death costs time only:** respawn ~5 s [PH] next to your own plot, lose
   nothing (`02-core-loop.md § Combat` has no death rule).
2. **Upgrade points come with the pickaxe tier** (Wooden 3, Iron 6 [PH]); each
   node (one rank of an upgrade, 3 ranks each [PH]) costs 1 point +
   resources; respec returns all points for a resource fee. Interpretation of
   § Pickaxe upgrade tree "limited points" and D92 "purchased".
3. **Iron pickaxe, armor and gadgets are crafted at Workshop I** (step 10);
   no buy menu. (§ Gadgets "crafted or bought": buying could come with NPC
   vendors later.)
4. **Shock Trap is thrown ahead, lands, arms, and stuns the first other
   player or Scav to touch it** (~1.5 s [PH], lasts 30 s [PH]). § Gadgets
   "Throwable, brief stun".
5. Interpretations, not asked: Smoke Bomb = cloud at your feet; nobody can
   target a player inside it from more than 4 studs [PH]. Walls block hits.
   PvP-protected players (FTUE rule 3) can neither hit nor be hit by players.
   Carry speed / Sprint recovery / Silent movement can be bought now; their
   effects arrive with the Chase and defenses. Note: **there is no sprint in
   the docs**, so "sprint recovery" has nothing to recover yet.

## Step 6 design-gap answers (2026-09-21) — NOT yet in `docs/`

1. **A Scav Wave fails when a Scav survives ~10 s [PH] at the Vault Core**
   (raised from 5 s in testing; Scavs now arrive along the plot's bridge,
   and can't loot through a wall; walled-in cores get climbed onto):
   it takes 2% [PH] of Exposed (resources + Scrap) and leaves. Kill every
   Scav = success. (04 § Scav Waves only says "failing costs Exposed".)
2. **Defenses fire only at Scavs and (step 7) raiders of that base**, never
   at visitors.
3. **Waves every 8–12 min [PH] while online, once you have a Vault Core;**
   the Captain leads ~1 in 4 [PH].
4. **Captain Rare and Signature buckets use stand-ins** until blueprints
   exist: Rare = 40 Research Scrap (until step 10's blueprints). Signature
   = the Captain pickaxe skin (v5.8; built with the skin system, 2026-09-22).
5. Interpretations, not asked: defenses are base pieces counting against
   the build budget plus a defense-slot cap per tier (2–5 [PH]); charges are
   public on the piece; Scavs go to a charged Decoy Vault first; Guard Drone
   zaps for small damage; a Scav blocked by walls hops over after 3 s [PH]
   ("never hard-block"); plain Scav kills drop a little Stone/Ore/Scrap to the
   killer.

## v5.8 (2026-09-21) — applied to `docs/` with Josh's double confirmation; built

Changed: `02-core-loop.md § Pickaxe upgrade tree` (Mobility row),
`04-world-content.md § The PvE ladder` (Homestead row), `05-items.md § Roll 1`
(Vaultborn row), `§ Vaultborn announcement`, `§ The Riftsalt rule`,
`10-roadmap.md` (v5.8 row), `00-README.md` (v5.8). **The design project still
needs the same edits.**

1. **"Sprint recovery" becomes "Stun recovery"** (Mobility branch,
   `02-core-loop.md § Pickaxe upgrade tree`): each rank shortens stuns and
   slows (Shock Fence, Shock Trap, Spike Floor). The docs have no sprint.
2. **Scav Captain Signature drop = a Captain pickaxe skin** (name [PH], e.g.
   "Captain's Cleaver"; `04-world-content.md § Loot table structure`). Pure
   cosmetic (R1/R3), tradeable like other earned skins (D111). Needs a minimal
   skin system. **Built** with the pickaxe skin system (2026-09-22).
3. **Vaultborn beam = a faint, fading, blinking beam** (Josh's own answer to
   review M2): easy to miss if you're scanning quickly, but a hypervigilant
   player can spot it. Replaces the steady instant beam (`05-items.md § Roll 1`
   Visual column, `§ Vaultborn announcement`). Blink rate, faintness and fade
   time are [PH] for the build.
4. **Zones carry a Contested flag** (`05-items.md § The Riftsalt rule`): the
   Reaches (and later the Rift) are Contested; the Homestead never is, even
   though PvP is on there. The server refuses a Riftsalt spawn point outside a
   Contested zone at start-up.

## Pickaxe skins (2026-09-22) — NOT yet in `docs/`

1. **An equipped skin replaces the whole pickaxe look;** the tier isn't shown
   (keeps tier a private power stat, like gear score, D92).
2. **A duplicate skin drop is kept as a spare** (tradeable in step 9, D111).

## v5.9 (2026-09-22) — applied to `docs/` with Josh's double confirmation

**Game renamed Vaultbreakers → Vault Raiderz** (GitHub repo `vault_raiderz`,
experience "Vault Raiderz"); **"Vaultbreaker Level" is now just "Level"**
(no title). 31 lines across 11 docs files + `00-README.md` v5.9 +
`10-roadmap.md` v5.9 row; history rows keep the old name. Code, CLAUDE.md
and docs-build renamed too. Not yet renamed: the local folder
`~/vaultbreakers` (Josh: later). **The design project still needs this.**

## Step 7 design-gap answers (2026-09-22) — NOT yet in `docs/`

1. **Offline bases appear on free plots** (recent leavers, shown for up to
   7 days [PH]), so scouting stays visual (02 § The raid sequence).
2. ~~Escape = off the victim's plot and its bridge.~~ **Superseded by D114**
   (escape radius, see "Main Street" below).
3. **Escort = one Roblox friend of the raider who opts in** when offered at
   breach (D101). Their hits don't knock the loot loose; defenses treat them
   as an intruder.
4. **One grab takes the whole theft share** (25% online / 8% offline,
   capped per tier [PH]).
5. **Lockpicking (2026-09-22, reworked from Josh's LOCKPICKING GUIDE):**
   Skyrim-style lock. Aim the pick (mouse / drag / right stick), hold
   **Turn** (D, W, Space, the TURN button, or right trigger). Each of the
   **3 stages** has a hidden sweet spot: dead on, the lock turns all the way;
   in the **partial zones** beside it, it turns part way (further the
   closer you are: the "getting warm" hint); outside, it barely budges.
   Holding Turn against the stop **shakes** the lock (less when close) and
   **wears the pick** until it snaps. Every stage re-rolls its sweet spot
   and lands on the **same side only 12%** of the time. Vault tier and
   Lock Upgrades make the stages narrower and picks break sooner; they
   never add stages. The raider **can't move while picking**; Cancel stands
   up and re-rolls the current stage (pick damage is kept).
   **Lockpicks are items** crafted from Ore at Workshop I (step 10). A snap
   costs one pick and a short refit; **with none left you improvise at ~35%
   turn speed**, never blocked, so 02 § Lockpick skill model ("speed, not
   success/failure") holds. The hidden turn direction was dropped (Josh).
   **Applied to docs/ (Josh confirmed twice, 2026-09-22):**
   `02-core-loop.md § The raid sequence` and `14-claude-code-prompts.md`
   Prompt 7 now say "Skyrim-style" instead of "timing-bar/timing
   minigame". **Still to copy into the design project.**
6. Interpretations: the 90 s window starts at breach (the Decoy "wastes ~20 s
   of the 90 s window"); tiers 5–7 sabotage = one defense offline 15 min,
   back by itself for free; a failed raid (knocked loose, died, left, time
   out) ends the raid.
7. **Engineering rule with a gameplay effect — APPROVED by Josh
   2026-09-23 (consistency report #13):** an offline base can be raided **at most once per absence**:
   after an offline theft the victim is "theft pending" until their next
   login. Needed so two raids can't take the same loot twice (review H2).
   Fits "offline raids capped low" (02 § Theft math).

## Main Street layout + escape radius (2026-09-22) — applied to `docs/` as D113/D114

From the claude.ai handoff `handoff-D110-D111-main-street.md`, applied with
Josh's double confirmation. **Renumbered:** the handoff called them D110 and
D111, but those numbers were already taken in the repo (D110 Harvester
Drone, D111 pickaxes untradeable, D112 armor), because the design project
hadn't received the earlier build-phase decisions. Repo: **D113** = Main
Street layout, **D114** = escape radius + carrier death; README **v5.10**,
nexus **v1.9**. **The design project needs:** D110–D112 copied in from the
repo, and its "D110/D111" renamed to D113/D114.

Build calls made while implementing (small, within the decisions):
- **Escape needs solid ground:** the radius only counts while the carrier is
  standing on something (`FloorMaterial` isn't Air). Without this, jumping
  off an island near the line could "escape" mid-fall and then die, which
  is the fall exploit D114 closes. Costs an honest carrier nothing
  noticeable (a jump delays it by under half a second).
- Config name is `Config.Raiding.EscapeRadiusStuds` (the handoff suggested
  `Config.ChaseEscapeRadius`), kept in the Raiding section with the other
  Chase numbers.
- Folder names kept: `World.Homestead` is now the street, `World.Bridge` the
  Reaches bridge; `World.Plaza` is new. So the art guide paths don't change.
- A plot's "front" (gate side, the side facing its bridge) is its local −Z
  edge = build-grid row z = 0 (`PlotGrid.front`). Scav lanes and death
  respawns use it; the server warns at start-up if a plot doesn't face its
  bridge.
- Homestead nodes: the FTUE Stone at (0, −18) in front of the spawn, 7 more
  Stone and 4 Ore at x = ±24 along the street, away from the bridge mouths.

## Consistency check decisions (2026-09-23) — applied to `docs/` with Josh's double confirmation

From `docs-build/consistency-report.md` Part B:
1. **#13 Offline raids:** keep one offline theft per absence; the 30-min
   post-raid shield (D75) starts at the victim's next login. (Already built.)
2. **#37 Spare armor theft (D112):** one grab takes the victim's **best
   spare** armor piece, whole (no in-transit destruction for a single
   item); the worn piece never (R1). **Built 2026-09-23** (missed in step 7):
   ArmorService.bestSpareIn/takeSpare/takeSpareVia; RaidService carries it
   through grab, escape (online, offline message, victim-left) and returns
   it on a failed raid.
3. **#40 Lockpicks and gadgets:** Workshop I crafts **basic** lockpicks and
   gadgets for everyone; Tech Path **Breaching** nodes unlock **better**
   versions. Step 10.
4. **#30 Q42** is missing from `08-questions.md`: check the design project.

The Part A doc fixes (38 + D93/label follow-ups) were applied to `docs/`
with Josh's double confirmation, 2026-09-23. **The design project needs
the same edits** (list: `docs-build/consistency-report.md` Part A).

## UI + Chase feedback (2026-09-23) — NOT yet in `docs/`

Josh's calls (options designed by a 4-agent workflow, chosen by Josh):
1. **The Bag:** one panel with tabs Resources | Gear | Items, split into
   SAFE (banked / worn) vs AT RISK (exposed / spare armor). Tap a resource
   for its Grades. Opened by a Bag button beside Raids, by tapping the
   vault meter, or by the Gear menu's Armor/Skin buttons (which replace the
   old per-piece rows that overflowed). Shown with the vault meter (R4).
2. **Chase progress:** the raider, victim and escort banners show the
   carrier's distance ("70/140 studs", 10-stud steps, server-computed); the
   victim gets one alert when the carrier passes halfway. No server-wide
   halfway ping (the Chase is ~15 s; the D58 queue would lag behind it).
3. **Raid log for both sides:** the raider also gets an entry ("You raided
   X: Got ..." / "Failed: <reason>"); failed raids record why.
Bug fixed alongside: raid log entries were never saved (map points were
negative; profiles reject negatives), so they're now stored shifted by
`Config.Raiding.LogCoordOffset`. This also restores the "applied" raid ids
that guard offline theft messages against being applied twice.

## Step 8 gap answers (2026-09-23) — NOT yet in `docs/`

Josh took all of Claude's picks:
1. **Raid band width** (02 § Preconditions "within the raider's band"):
   raiding UP is always allowed; raiding DOWN at most **1 band** [PH]
   (`Config.RaidProtection.MaxBandsBelow`).
2. **Charge cost:** flat **1 Breach Charge per raid** [PH], not scaled by
   target tier. Recipe **3 Riftsalt → 1 charge** [PH invented].
3. **Where to craft:** a Craft row on the Bag's Items tab, anywhere, until
   Workshop I (step 10) exists. Spend order = the step 4 rule.
4. **Shielded raiders:** breaching a player's base **ends your own shields**
   (48-hour and post-raid). The first Breach while shielded is refused with
   a warning; Breach again within 10 s [PH] to confirm.
5. **Seeing your shield:** a countdown row at the top of the Bag's Resources
   tab, not on the HUD (FTUE rule 1, R4).
6. **Stealing Breach Charges** (05 § Taxonomy says stealable): deferred to
   the backlog; raids still take only Exposed resources + a spare armor piece.
7. **Escorts are band-checked too (D101):** a friend is only offered / can
   only join an escort if the target is in THEIR band (same MaxBandsBelow
   rule). Claude's interpretation of R6; **Josh confirmed (2026-09-23)**.
   The docs say nothing about escorts and bands.
Also built as documented: both shields block online AND offline raids; the
30-min shield starts at the login that applies an offline theft (#13);
offline bases are only shown if someone on the server can raid them.

## Chase grip + raid-time respawn (2026-09-23) — PROPOSED, not built, not in `docs/`

Found in step 8 testing: one hit knocks the loot loose (02 § The Chase point
5, LOCKED) + a single bridge per plot (D113) + respawn on your own plot
(step 5) = an owner camping their bridge end stops every raid, and killing
them doesn't help (they respawn beside the raid). Josh's preferred fix:
**grip limit** (loot drops after 30 [PH] damage while carrying, not one hit)
**+ die during a raid on your base → respawn on Main Street**. Changes a
LOCKED rule, so it goes to the design project first:
`docs-build/handoff-2026-09-23-chase-grip.md` (suggests D115).
Josh's detail answers (§4 of the handoff): flat 30, no recovery, player hits
only, bar for carrier + owner, owner-only Main Street respawn while their
base is raided, spawn point is the only change.

## "Your plot" marker (2026-09-23) — NOT yet in `docs/`

Found on the first phone test: plots are given automatically (D113), you
spawn mid-street, and the Build button only shows on your own plot, so a
new player couldn't tell which plot was theirs and never saw Build.
Josh's call (chosen over "Build button anywhere", "spawn on your plot" and
"pick a plot"): **keep plots given; a pulsing light beam + bouncing arrow
over your own plot, seen only by you, while you're off it.** No words (FTUE
hard rule 1). Shown with the Build UI, so step 14's FTUE controls it
(0:45 "BUILD VAULT"). Plots are per server, so a returning player may be on
a different plot each visit; the marker covers that too.
`src/client/PlotMarker.client.luau`, `Config.Base.BuildUi.PlotMarker`.

## Flagged for redesign (step 2 review, 2026-09-20) — ANSWERED 2026-09-21 (see above)

Answered in v5.8 (see the v5.8 section above); kept for history. The text
below is the original flag.

1. **Vaultborn beam vs "zone-level, not coordinates" (review M2).** The
   beam appears at the exact node, instantly, for every player, while the
   announcement is zone-only and 30 s late (`05-items.md § Vaultborn
   announcement`, `§ Roll 1` Visual column). The beam gives away the
   position the announcement hides. Options to weigh: beam seen only
   nearby; beam delayed to match the announcement; no beam for Vaultborn;
   keep as is (the holder can walk away).
2. **Riftsalt placement is enforced only by map data (review L1).**
   `05-items.md § The Riftsalt rule`: "contested zones only". Today it holds
   only because no Homestead spawn point is a Riftsalt one. Design question
   first: which zones count as "contested" (Reaches only? Rift later?) and
   should zones carry that as data? Then a start-up check can refuse a
   Riftsalt spawn anywhere else.

## Wider Main Street (2026-09-23) — NOT yet in `docs/` (sizes are [PH])

Josh: the street felt like a runway, so the grass on each side of the road
was tripled. `02-core-loop.md § Slice layout` "Starting sizes [PH]" is now
out of date; live values are in `docs-build/worldgen/gen_world.py`.
- Street 96 × 320 → **240 × 320** (24 road + 108 grass each side).
- Plaza 176 × 96 → **240 × 96** (matches the street width).
- Plot rows moved out (row centre x 136 → 208) so **bridges stay 64**; plots,
  escape radius (D114) and Scav lanes unchanged.
- Costs: crossing to the opposite plot ~15 s (was ~6 s); facing plots
  368 studs apart (was 224); average plot → Reaches walk ~+2–3 s against
  D113's ~25 s [PH] target.
- Mock scenery added at the same time: 22 more trees + 36 walk-through
  bushes, seeded (`street_scenery()` in `gen_world.py`). Placeholder art.

**To go back** (edit `docs-build/worldgen/gen_world.py`, then run
`python3 docs-build/worldgen/gen_world.py` and restart `rojo serve`):
- Double the grass: `STREET_SIZE = (168, 320)`, `PLAZA_SIZE = (176, 96)`.
- Original: `STREET_SIZE = (96, 320)`, `PLAZA_SIZE = (176, 96)`.
- Nothing else: plot rows follow the street width, so bridges stay 64, and
  the scenery re-scatters to fit.
