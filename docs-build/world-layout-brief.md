# Vault Raiderz: world layout brief (for a layout redesign)

> **Historical (2026-09-22):** this brief led to D113 "Main Street", which
> replaced the ring layout described below. Current layout:
> `docs/02-core-loop.md § Slice layout` and `docs-build/worldgen/gen_world.py`.

Written 2026-09-22 by Claude Code from the actual repo, for another Claude
(in claude.ai chat) to recommend **alternative island / plot layouts**.
Everything here is either **[Measured]** (from the code/world files or a
real device test), **[Design]** (a locked or placeholder rule in the design
docs), or **[Platform]** (general Roblox knowledge; verify before relying on
it). Numbers marked `[PH]` are placeholders nobody has tuned yet: they can
change freely.

## 0. What I'm asking you (the reader) to do

Propose **3–5 alternative world layouts** to the current one (section 2).
For each one give:

1. A top-down sketch (ASCII is fine) with sizes in studs and distances.
2. What it improves (fairness, the Chase, scouting, travel, FTUE, feel).
3. **Cost to build now**, using the cheap / medium / expensive table in
   section 7. Say exactly which rows it touches.
4. Which rules in section 3 it bends, if any. **Never silently break a
   `[LOCKED]` rule**; if an idea needs one changed, label it "needs a
   design change" and say which.
5. Render cost versus section 4: how many plots/islands are on screen at
   once and roughly how many triangles that is.

Please stay inside what's buildable at this dev stage (section 1). Ideas
for later (the Rift, the Exchange, fast travel) are welcome **only** as
"reserve space for it" notes, not as something to build now.

---

## 1. Where the project is

- **Game:** Vault Raiderz, a Roblox game (Luau + Rojo). Floating islands:
  mine resources, bank them in a Vault Core on your own plot, build walls and
  defenses, raid other players' bases, and escape in "the Chase" while anyone
  can knock the loot loose. **Mobile-first** audience.
- **Stage:** building the **vertical slice** (a small playable version to test
  retention). Build steps 0–7 of 14 are done: data, mining, vault/bank, plots +
  base building, combat, defenses + NPC Scav waves, raiding + lockpick + Chase.
  **Next:** step 8 (Breach Charges + Riftsalt + raid bands + shields), then 9
  (NPC selling, trading, Level), 10 (Workshop I, Tech Path), 11 (Crews),
  12 (offline production), 13 (analytics), 14 (first-time player tutorial).
- **Art:** everything is **greybox** (plain Roblox parts). An artist will
  reskin later; **no final art exists yet**, so **layout changes are at
  their cheapest right now**.
- **How the world is made:** a Python script
  (`docs-build/worldgen/gen_world.py`) writes the islands, plots and bridges
  as files that Rojo syncs into Studio. Changing the layout = editing numbers
  and shapes in that script (plus Config), not hand-placing parts.
- **Solo developer** new to Roblox, with Claude Code writing the code.

---

## 2. The current layout [Measured]

All walkable surfaces sit at **Y = 50**. North = −Z. Units are studs
(a default Roblox character is about 5 studs tall).

```
                      ┌──────────────┐
                      │   REACHES    │ 150 x 150, centre (0, -430)
                      │  contested   │ Ore x6 + Riftsalt x5 spawn points
                      └──────┬───────┘ (3 Ore + 2 Riftsalt live at once, they move)
                             │ bridge 12 wide x 245 long
          P8 ╲               │               ╱ P1
              ╲      ┌───────┴───────┐      ╱
                     │   HOMESTEAD   │
      P7 ─────────── │   220 x 220   │ ─────────── P2
                     │  spawn + 8    │
              ╱      │ Stone, 4 Ore  │      ╲
          P6 ╱       └───────────────┘       ╲ P3
                   ╱                   ╲
                 P5                     P4
```

| Piece | Size (studs) | Where | Notes |
|---|---|---|---|
| Homestead (hub island) | 220 x 220, 10 thick | centre (0, 0) | Player spawn at (0, 70). 8 Stone + 4 Ore node spawn points, fixed respawn 30 s. Zone "Homestead": PvP on, **not contested**. |
| Reaches | 150 x 150 | (0, −430) | Zone "Reaches": **contested**. Ore (6 spots) + Riftsalt (5 spots); nodes "deplete and migrate" (45–90 s, a different spot). |
| Reaches bridge | 12 wide x 245 long | north side | The only way to the Reaches. |
| Plots 1–8 | 48 x 48 each (12 x 12 build cells of 4 studs) | ring of radius 200 around the Homestead centre, arc from −30° to 210° (north left free for the Reaches bridge) | Small floating islands, **all axis-aligned** (not rotated). One plot per player. |
| Plot bridges 1–8 | 8 wide, **33 to 70 long** | radial, Homestead edge to plot edge | One bridge per plot, straight. |

**Things that are wrong or weak about it now [Measured]:**

- **Unequal bridges.** The Homestead is square and the plots sit on a circle,
  so bridges are 33, 49, 64 or 70 studs long depending on the plot. The bridge
  length sets both **Scav warning time** and **Chase escape distance**, so
  some plots are easier to defend or raid than others.
- **Plots aren't rotated to face their bridge.** A saved base is stored in
  the plot's own grid, and players get whichever plot is free each session.
  So a gate built facing the bridge on Plot 2 faces a different direction
  on Plot 5.
- **Short Chase.** A loot carrier moves at 9.6 studs/s and escapes by getting
  off the victim's plot **and** its bridge: about **6–10 s** of running.
- **Long, empty Reaches trip.** Homestead centre to the Reaches centre is about
  430 studs, **~27 s** of walking with nothing on the way.
- **Everything is one height**, and plots are small flat squares.
- The screenshot's top island is the Reaches; the green square is the
  Homestead; the 8 small squares are plots (yellow dot = centre marker).

---

## 3. Rules the layout must respect

### Locked design rules `[LOCKED]` (need a design change to break)
- **Zones (02 § World Structure):** a floating archipelago with risk rising
  outward: the Exchange (safe hub; market, NPC vendors, public Workshop I),
  the **Homestead Ring** (player plots, PvP on, raiding on), **the Reaches**
  (contested rare nodes), **the Rift** (legendary; bosses). **The slice ships
  only the Homestead + a small Reaches** (D107).
- **Scouting is visual:** "bases are visually tiered from a distance...
  target selection is visual, not a menu." Plots must be **visible from
  other places**, from the air or across gaps, so hiding plots entirely
  works against the design.
- **Riftsalt spawns only in contested zones** (the Reaches now, the Rift
  later). The code **refuses to start** if a Riftsalt spawn point sits in a
  non-contested zone. The Homestead is **never** contested (even though PvP
  is on there).
- **Server sharding (D56/D79):** each server hosts a **bounded, tier-matched
  set of plots**; players far outside your band are seen via a lighter map
  view, not by flying over. Plot count per server is `[PH]` (currently 8 =
  the server's max players).
- **One plot per player**, assigned when they join; offline players' bases
  are shown on free plots (always keeping 1 plot free for a joiner) so they
  can be raided.
- **Build budget (D57):** every placed piece costs "render weight" against a
  tier-scaled budget (40 at tier 1 to 300 at tier 7, `[PH]`).
- **Raids:** 90 s window from breach. Escape = off the victim's plot and its
  bridge (a build-phase call; the doc says "to the zone boundary").
- **The Chase:** the carrier is slowed, marked server-wide, and **any hit
  knocks the loot home**. Third parties crashing the Chase is the headline
  moment, so geography that makes the Chase visible and contestable helps.
- **Scav waves** arrive **along your plot's bridge**, starting 60 studs from
  the plot centre, so waves give ~5–8 s of warning.
- **FTUE (first-time player) spec:** spawn **facing a glowing node**, mine,
  place a Vault Core by ~1:00, fight one Scav, then at 4:00–6:00 raid a
  **"derelict NPC vault"** (location not decided yet).
- **Mobs never destroy structures; nothing is permanently lost below vault
  tier 8** (the slice stops at tier 7).
- **Mobile-first:** readability at phone size, thumb controls; big empty
  walks hurt short sessions (target session 15+ min in the slice).

### Not locked / open: good places for a layout to help
- **Where the NPC buyer (step 9) stands:** not specified. The design puts
  vendors in the Exchange, which isn't in the slice.
- **Where the FTUE "derelict NPC vault" is:** not specified.
- **Workshop I** is a **placeable building on your own plot** (step 10), so
  plots need room for it inside the budget.
- **Fast-travel pads** between zones are in the design ("unlockable"),
  but **not in the slice list**, so treat them as "reserve space".
- Plot size, plot count, island sizes, bridge shapes, heights: all `[PH]`.

---

## 4. Performance and memory budget

### Design budget [Design] (09 § Rendering & Mobile Performance Budget)
| Constraint | Limit |
|---|---|
| Scene draw calls (baseline cheap phone) | ~1,000 |
| Scene triangles (baseline cheap phone) | ~1,000,000 |
| Triangles per MeshPart (import cap) | ~20,000 |
| Texture resolution | 1024 x 1024 max |

It must cover **your base + every visible neighbour base + particles** at
once. The docs call LOD and culling of neighbour bases "load-bearing".

### Real device test [Measured] (build step 0B, 2026-09-20)
Scene: your base in the middle of a **3 x 3 grid of islands (you + 8
neighbours)**, each a stand-in "mid-tier base" of 28 pieces / **~25,000
triangles**, plus 12 nodes with particles and 4 NPCs. Device: **iPhone 14
Pro Max** (a flagship; **no cheap phone has been tested yet**).

| Scene | Real triangles | GPU ms (of a 16.7 ms frame) | Draw calls | App memory |
|---|---|---|---|---|
| 1 base | 78k | 4.3 | 32 | ~830 MB |
| 9 bases, varied materials | 293k | 6.8 | 125 | ~920 MB |
| 9 bases x 4 detail | 658k | 14.3 | 65 | ~955 MB |
| 9 bases x 16 detail (3,639 parts) | 2.1M | 15.4 | 65 | ~1,030 MB |

What it means:
- **60 FPS everywhere on the flagship**, no crash, even at 2.1M triangles.
  That's a **best case**; a cheap phone will be several times slower.
- **Draw calls don't grow with piece count**: identical parts/meshes batch.
  **Different materials split batches** (varied materials doubled draw
  calls, 65 to 125). Fewer materials and repeated pieces are cheap.
- **Triangles on screen drive GPU time.** 2.1M on screen is near this
  phone's limit, so **~1M on screen** stays the working ceiling.
- **Memory climbs and doesn't come back** (830 MB to 1.03 GB over a session).
  There's no documented memory limit; low-end phones will kill the app well
  before a flagship does (exact threshold unknown, not measured).
- The test only covered **you + 8 neighbours**. **More than ~9 bases on
  screen at once is untested.**
- Automatic LOD removed nothing on these small meshes, and scripts **can't**
  set mesh LOD/RenderFidelity (it's a Studio-only property), so we can't
  count on LOD to save a crowded view.

### Rules of thumb for a layout
- Budget about **~25k triangles per visible base** (mid-tier) plus the
  islands themselves. Nine bases in view ≈ 225k + terrain/islands. Twenty
  bases in view would need LOD or distance culling we haven't built.
- A layout that shows **all plots from one spot** (like the current ring)
  is fine at 8 plots. A layout with more plots should break line of sight
  (heights, rock spires, fog) or spread them out, instead of expecting more
  GPU headroom.
- Keep island materials few (grass, rock, wood); reuse shapes.

---

## 5. Data and file-size limits

| Limit | Value | Source |
|---|---|---|
| Saved data per player key | 4 MB | [Platform] Roblox DataStore per-key limit |
| Whole-experience DataStore storage | 500 MB + 1 MB per lifetime player (from July 2026) | [Design] 09 § Data Architecture (verify) |
| A saved base | List of pieces: `{Kind, X, Z, Rot}` in **plot grid cells** (~50 bytes each; a max base is a few hundred pieces) | [Measured] |
| Mesh | ≤ ~20k triangles per MeshPart | [Design] |
| Texture | ≤ 1024 x 1024 | [Design] |
| World geometry | Generated parts (JSON via Rojo), not saved per player | [Measured] |

**What this means for layout:** the world itself costs **no player save
space**; only bases do. But because bases are saved **in plot grid
cells**:
- **Every plot must be the same size and shape** (a player gets a different
  plot each session). Pieces that don't fit are skipped (kept in the save,
  not shown).
- **Plots can grow safely** (old bases still fit). **Shrinking** plots hides
  pieces for existing testers (only testers exist right now, so it's still
  cheap).
- Plots can be **rotated** freely (the grid follows the plot's rotation), so
  "every plot's bridge enters the same side" is possible.
- Plots are **rectangles** (one flat Hitbox part). Round or L-shaped build
  areas would be a real code change.

---

## 6. Movement and distance numbers

| Thing | Value | Source |
|---|---|---|
| Walk speed | 16 studs/s | [Measured] Roblox default |
| Jump | JumpPower 50: about 6 studs up, about 8 studs across at a run | [Platform] (physics estimate) |
| Loot carrier (the Chase) | 9.6 studs/s (0.6x) | [Measured] |
| Scav walk speed | 12 studs/s | [Measured] |
| Raid window | 90 s from breach | [Design] |
| Breach range | within 10 studs of the victim's plot edge | [Measured] |
| Build reach | within 30 studs of your plot | [Measured] |
| Falling off an island | the character dies and respawns at your own plot, losing nothing | [Measured] + [Platform] (Roblox destroys parts that fall below Y = −500) |

Handy conversions: crossing the Homestead = ~14 s; Homestead to Reaches =
~27 s; a 50-stud bridge = ~3 s walking, ~5 s carrying loot. **Gaps over
~8 studs can't be jumped**, so every island needs a bridge (or a launch pad
or fast-travel pad, which aren't built). Keep the whole world within a
few thousand studs of the origin; very large coordinates cause physics
jitter on Roblox [Platform].

---

## 7. What's cheap, medium, or expensive to change now

### Cheap (numbers in the world script + Config, about an hour)
- Island sizes and positions; Homestead shape (square, rectangle).
- Plot **count** (with the server's max players to match), **size** (same
  for all), ring radius, arc, spacing, **rotation** (e.g. all face their
  bridge).
- Bridge lengths, widths and positions (each **one straight part**).
- **Splitting the Homestead or Reaches into several islands** with the same
  zone (the node system already pools spawn points by zone across islands).
- Moving node spawn points; moving the player spawn.
- Heights **per island** (the code doesn't assume Y = 50 anywhere except
  generation).
- Rocks/spires/decor for line-of-sight breaks (they're Visual only).

### Medium (small code changes, a session)
- **Curved or multi-segment bridges.** Escape checks and Scav spawning
  assume one straight bridge part per plot.
- **More than one bridge per plot**, or plots reached through another
  plot.
- A **new zone** type (needs a Config zone entry; contested or not).
- Scav spawns that don't use the bridge.
- Placeholder spots for the step-9 NPC buyer and the step-14 derelict
  vault (just positions + a tag).
- Changing what "escaped" means (e.g. "reach the zone boundary", as the doc
  says, instead of "off the plot and bridge").

### Expensive or not now
- **More than ~9 bases visible at once** (render budget untested; no LOD).
- **Real sharding** (multiple neighbourhoods, a map view of other shards).
  It's a stub: one neighbourhood per server.
- **Terrain** (Roblox smooth terrain) instead of parts: possible, but the
  mining line-of-sight check would need updating, and it's a new art
  pipeline for the artist.
- **Fast travel / launch pads**, moving islands, vehicles, flight: not in
  the slice.
- Building the **Exchange hub, the Rift, or Deep Reaches**: out of the slice
  (D107). Reserve space only.
- Round or irregular build areas (the build grid is rectangular).

### Every layout must keep (code depends on it)
- Islands with nodes are **direct children of the World folder** with a
  `Zone` attribute and a `NodeSpawns` folder.
- Each plot is a Model tagged `Plot` with a `PlotIndex` and a flat
  rectangular `Hitbox`; its bridge is `Bridge<index>` beside it.
- Scavs need ground **~60 studs from the plot centre toward the bridge**
  (or they fall back to the plot edge).
- All plots identical in size.

---

## 8. Ideas already worth considering (not decided)

- Make **all plot bridges equal length** (circular hub, or plots on a
  square around a square hub) for fair Scav warning and Chase length.
- **Rotate plots** so the bridge always enters the same side of every plot.
- Put something **between** the Homestead and the Reaches (a mid-island,
  the NPC buyer, the derelict FTUE vault) so the 27 s walk isn't empty.
- Use **height** (plots on different levels, lookout points) to make
  visual scouting a skill without putting more bases on screen.
- Longer or branching routes off each plot so the **Chase lasts long enough**
  for third parties to intervene (the doc's headline moment), without
  making defence impossible.

## 9. Please don't recommend (without flagging it as a design change)

- Riftsalt anywhere non-contested; the Homestead becoming contested.
- One shared world with all players' plots (rejected in D56).
- Hiding bases from view entirely (scouting is visual).
- Systems outside the slice as if they're buildable now: global market,
  Rift bosses, farming/greenhouses, pets, vehicles, Robux items.
- Relying on automatic LOD or scripts changing mesh detail at runtime.
- More than ~9 bases rendered at once without saying how (spacing, height,
  or occlusion) keeps it under ~1M triangles on a cheap phone.
