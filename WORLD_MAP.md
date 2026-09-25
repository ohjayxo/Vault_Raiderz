# WORLD_MAP.md — Vault Raiderz R1 map: The Quarry

**Status:** ACTIVE · **Version 1.0** (2026-09-24). Written in the claude.ai
design project. Companion to `REWORK.md` v1.3 (§19 points here).
**Goes in:** the repo root, next to `REWORK.md` and `CLAUDE.md`. Reference
drawing: `docs-build/worldgen/WORLD_MAP.svg` (top-down, to scale).
**Replaces:** D110 (Main Street), RW7 (168-stud street) and D110's plaza
placement. `docs/` is frozen; don't edit it to match.
**Authority:** this file wins on **positions, shapes, spawns and map
dressing**. `REWORK.md` wins on **system rules and system numbers**. If
they seem to disagree, stop and ask Josh (Prompt G).
**Numbers:** every number is `[PH]` unless stated. Put them in
`Config.World` (in `src/shared/Config.luau`) with a comment naming the
section, for example `-- WORLD_MAP §3 [PH]`. Tune freely; log only rule
changes in `REWORK.md` §18.
**Layout is locked for R1.** Don't add map features that aren't in this
file. New ideas wait for R1-15 playtest data.

---

## 0. How to use this file (Claude Code)

- Read `REWORK.md` first, then only the sections of this file that your
  current R1 item lists. Build items: **R1-08a** (geometry), **R1-08b**
  (plot order and spawns), **R1-08c** (dressing and legibility). Pieces
  also land in R1-05, R1-06, R1-11, R1-12b, R1-13 and R1-14.
- **R5 still rules:** the server decides every position check, spawn,
  respawn and zone rule. Anything marked *client-only* is visuals or sound
  driven by state the server already sends; it never changes an outcome.
- **Greybox contract:** Hitbox + Visual, code never touches Visual. Colour
  (§12) is applied to `Visual` only.
- **Reuse before you add.** Tag and service names below are suggestions.
  If an existing tag, service or model already does the job, extend it
  and say so in your summary.
- Every geometry rule in §4 has a check in §21. Don't mark R1-08a or
  R1-08c done until those checks pass.

---

## 1. The concept and the names

An old open-pit quarry floating in the sky. Eight plot islands sit around
its **Rim**. A railed ring road at plot height joins them. The ground
slopes down into the **Pit**, where the Rich Veins erupt. The crystal
**Spire** stands at the centre over the **Burrow**, the only place Scavs
come from. In the north, the **Gate** island holds the Scav Camp in front
of a colossal half-buried vault door. In the south, the **Plaza** is the
safe hub and first spawn.

Use these five names everywhere players see words (banners, the vein
warning, UI): **the Rim, the Pit, the Burrow, the Gate, the Plaza.**

---

## 2. Coordinates

- Studs. Map centre (the Spire) at X = 0, Z = 0. North = −Z.
- Angle **θ** is measured clockwise from north, seen from above:
  `X = r · sin θ`, `Z = −r · cos θ`.
- Walkable Rim height: **Y = 50** (the current build's walkable height).
  Pit floor: Y = 36.
- If the current `gen_world.py` uses a different origin or Y, keep its
  convention and translate these numbers; say so in the summary.

---

## 3. Geometry

### 3.1 Pieces

| Piece | Size [PH] | Position [PH] | Y [PH] | Notes |
|---|---|---|---|---|
| Rim slots | 10, every 36° | θ = 0°, 36° … 324° | — | 0° = Gate, 180° = Plaza, other 8 = plots |
| Plot islands | 48 × 48 | centre r = 216 | 50 | Gate side faces the centre; build grid follows rotation |
| Plot bridges | 8 wide × 32 long | r = 160 → 192 | 50 | One straight piece each, all identical |
| Rim road | ring r = 136 → 160 | — | 50 | Everyday walking; never touches a plot |
| Rim rails | waist-high | outer edge of the Rim road | 50 | Gaps only at bridge mouths |
| Slope | ring r = 112 → 136 | — | 50 → 36 | ~30°, walkable everywhere, no jumps, no steps |
| Pit floor | disc r = 112 | centre | 36 | Vein ring, Spire, Burrow, compass mosaic |
| Spire | base ~10 across, ~60 tall | centre | 36 → ~96 | Non-climbable (§5) |
| Burrow grate | ring r ≈ 6 → 16 | around the Spire base | 36 | Solid for players, never enterable |
| Gate island (Scav Camp) | 96 × 64 | centre r = 222, θ = 0° | 50 | Spans r 190 → 254; 12-wide bridge r 160 → 190 |
| Plaza island | 120 wide × 88 deep | r = 190 → 278, θ = 180° | 50 | 20-wide bridge r 160 → 190; layout §9 |
| Reaches bridge | as built | from the Gate island's north edge | 50 | Passes through the vault-door gap; **barricaded** in R1 (`Features.Reaches = false`) |
| The Reaches | as built | north of the vault door | — | Unchanged position; unreachable in R1 |
| Cloud deck | visual layer | under the whole island | ≈ −100 | Client-only look |
| Kill plane | — | everywhere | ≈ −120 | Below the cloud deck; falls respawn per §10 |

### 3.2 Plot table (computed from §3.1)

Fill slot = the order online players get plots (§10).

| Fill slot | θ | X | Z | Yaw |
|---|---|---|---|---|
| 1 | 144° | 127.0 | 174.7 | gate faces the centre |
| 2 | 108° | 205.4 | 66.7 | gate faces the centre |
| 3 | 216° | −127.0 | 174.7 | gate faces the centre |
| 4 | 252° | −205.4 | 66.7 | gate faces the centre |
| 5 | 72° | 205.4 | −66.7 | gate faces the centre |
| 6 | 288° | −205.4 | −66.7 | gate faces the centre |
| 7 | 36° | 127.0 | −174.7 | gate faces the centre |
| 8 | 324° | −127.0 | −174.7 | gate faces the centre |

`PlotIndex` can stay as built; add a `FillSlot` attribute (1–8) so
assignment order doesn't depend on index order.

### 3.3 Checked distances (from the §3.1 numbers)

| Check | Value |
|---|---|
| Gap between neighbouring plot islands | 73 studs |
| Plaza island ↔ nearest plot island | 39 studs |
| Gate island ↔ nearest plot island | 50 studs |
| Rim road ↔ Gate and Plaza islands | 30 studs |
| Rim road ↔ plot island (void under the bridge) | 32 studs |
| Plot → centre, on foot (16 studs/s) | ≈ 13.5 s |
| Plaza spawn → fill slots 1 / 3 | ≈ 8 s |
| Plaza spawn → fill slots 2 / 4 | ≈ 15 s |
| Plaza spawn → fill slots 7 / 8 (farthest) | ≈ 25 s |
| Snatcher run, plot → Burrow at 14.5 studs/s | ≈ 15 s, identical for all 8 plots |
| D111 Chase escape (140 studs from plot centre) | reached near the Pit centre (r ≈ 76) or about one plot along the Rim |
| Outermost walkable points | plots r ≈ 241 · Gate r ≈ 259 · Plaza r ≈ 284 |

---

## 4. Map-wide safety rules

1. **Height rule (no drop-ins):** no public walkable surface within 40
   studs (horizontal) of a plot is higher than that plot's floor. Plots
   are the highest public ground.
2. **Island gaps:** every island (plots, Gate, Plaza) is separated from
   every other island and from the Rim road by ≥ 30 studs of void, except
   along its own bridge. No running jump can skip a bridge.
3. **Unreachable scenery:** every scenery surface (§15) sits behind
   ≥ 30 studs of void from any walkable surface. In practice: scenery
   starts at r ≥ 275, r ≥ 290 behind the Gate, and r ≥ 315 behind the
   Plaza (θ 150°–210°). No scripts on scenery, `CastShadow` off,
   `CanCollide` off wherever a player can't touch it anyway.
4. **Decor rule:** decor within 40 studs of a plot has no standable
   surface above 3 studs; otherwise it is `CanCollide = false`. No
   `TrussPart`, ladders or climbable ledges anywhere public.
5. **Juke-cover limit:** gameplay props in the Pit are ≤ 8 studs across
   at ground level and have nothing standable above head height.
6. **Everything is equal per plot:** plot size, bridge length, distance
   to the Burrow and distance to the Pit centre are identical for all 8.

---

## 5. The Spire and the Burrow

**Spire.** A non-climbable crystal spire at the centre. Smooth sides, no
ledges, no truss. Visuals (client-only, from existing server events on the
D58 broadcast queue): idle slow glow; during a vein countdown a beam leans
toward the next vein spot; during an active Chase it pulses red. Stone
rings orbiting it are an "R1 if time" item (§14).

**The Burrow is the only Scav spawn on the map.** Scav Camp guards stay
at the camp; nothing else spawns hostile NPCs in R1.

- **Emergence:** each wave Scav climbs out of the side of the Burrow ring
  that faces its target plot, 0.5 s apart [PH]. Waves read at a glance and
  never clump (clumped NPCs cost physics).
- **Path:** Burrow → the target plot's Scav ground (existing contract:
  ~60 studs from the plot toward its bridge, which lands on the Rim road).
- **Target lock:** wave Scavs and Snatchers ignore players unless that
  player hits them or is defending the target plot (standing on it or its
  bridge). Anyone can still hit them; the interceptor bounty is unchanged
  (`REWORK.md` §7.2). This keeps the Pit safe for miners and new players.
- **Snatchers** (`REWORK.md` §6.2) run from the pedestal to the Burrow at
  **14.5 studs/s** [PH] (still slower than a running player's 16).
  Reaching the Burrow moves the gem to Held by Scavs (RW10). Tune
  `SnatcherSpeed`, never geometry.
- **Captain waves** (~1 in 4): the grate swings wide and the Spire pulses
  (client-only look) before the Captain climbs out.
- **Live-Scav cap:** ~24 [PH] Scavs alive across the map, alongside D59's
  concurrent-wave cap. Overflow queues the same way.
- **Telegraph:** the grate rattles, puffs dust and plays scratching audio
  for 5 s [PH] before any wave (client-only, from a server event).
- **Between waves:** glowing eyes under the grate (client-only). No bodies.
- **Juke cover:** 3 low mine carts ~24 studs [PH] from the centre at
  θ 30°, 150°, 270° (§4 rule 5).
- Held back to R2: "Scav scout" wanderers, only if the funnel shows dead
  stretches between waves.

---

## 6. Mining nodes

- **8 Stone + 4 Ore** as 6 pairs on the slope at θ = 18°, 90°, 162°, 198°,
  270°, 342°. Each pair: one node at r ≈ 118, one at r ≈ 128 [PH]. The
  θ 90° and 270° pairs are **Ore**; the other four pairs are **Stone**.
- Keep clear of bridge mouths. Pairs are spaced so Resonance nodes
  (D102, R2) become a switch, not a map edit.
- **FTUE first node:** one Stone node on the Rim road just outside the
  Plaza bridge (r ≈ 148, θ ≈ 170° [PH]), visible from the Plaza spawn.

---

## 7. Rich Vein spots

- 3 spots on a ring in the Pit (r ≈ 66 [PH]) at θ = 60°, 180°, 300°.
  Never within 40 studs [PH] of the Plaza spawn (R6).
- Rules, odds and timing: `REWORK.md` §11 (unchanged).
- Looks (client-only): dormant spots show a faint cracked ring and a
  glowing seam crack running toward the Burrow; erupting spots follow §16.

---

## 8. The Gate (Scav Camp)

- The Scav Camp sits on the Gate island (θ 0°). Reuse the derelict-vault
  model and lockpick; rules in `REWORK.md` §6.3.
- **The camp's exit faces the bowl.** Camp escapes run onto the Rim road,
  where interceptors are, never toward the void. The camp's 60-stud escape
  radius (`REWORK.md` §6.3) ends where the Gate bridge meets the Rim road.
- **Camp door light:** green = this player can raid; red = their cooldown
  (client-only, from the §6.3 cooldown the server already tracks), next to
  the §6.3 door timer.
- **Vault door:** a colossal half-buried vault door forms the north cliff
  behind the Gate (scenery, §15). The barricaded Reaches bridge runs into
  its gap. Its giant dial turning a notch each time a Rich Vein ends is an
  "R1 if time" look (§14); the door opening is the R2 Reaches event.
- Searchlights sweeping from the camp over the Pit: "R1 if time" (§14).

---

## 9. The Plaza (truce square)

### 9.1 Truce rules (R1-14)
- The whole Plaza island is a truce zone: player hits deal **no damage and
  no knockback** inside it, **except hits on a carrier** (grip still
  drains). Checked on the server from trusted positions (R1-00).
- **No hit-and-hop:** a player who dealt or took player damage in the last
  5 s [PH] gets no truce protection until that timer ends.
- Scavs never path into the Plaza.
- `Features.TruceSquare = true`.

### 9.2 Layout (6 stations max)
Local frame: **front** = the edge facing the bowl (north), **left** = west.
Depths are measured inward from the front edge [PH].

| Spot | Where | Phase |
|---|---|---|
| Welcome arch + first spawn | front edge, centre; spawn 8 studs inside, facing the bowl | R1 |
| Overlook ledges (railed) | front edge, both sides of the arch | R1 |
| NPC buyer | left, depth ~28 | R1 (`REWORK.md` §9.3) |
| Brazier + seats (built-in `Seat` parts) | centre, depth ~30 | R1 |
| Crafting Bench | right, depth ~28 | R1 (`REWORK.md` §9.2); keeper gives daily quests in R2 |
| Shop | back left, depth ~66 | Public launch; position + tag only in R1 |
| Event pad | back centre, depth ~66 | R2 (one temporary machine per event); tag only in R1 |
| Board (records / Most Wanted) | back right, depth ~66 | R2; tag only in R1 |

- Leave the rest as open floor on purpose (meeting friends, standing
  around, watching the Pit).
- **Hard cap: 6 stations.** A new station must replace or merge with an
  existing one. Daily reward and friend invites are UI prompts, not
  stations.
- Shop rules for launch: `REWORK.md` §16.

---

## 10. Plot fill order, spawns and respawns (R1-08b)

- **Fill order:** online players get the lowest free fill slot (§3.2):
  nearest the Plaza first, alternating sides.
- **Friends:** a joining Roblox friend of a player already on the server
  takes a free plot next to that friend (adjacent fill slot on the same
  side), else the lowest free slot.
- **Offline display bases** (`REWORK.md` §7.1) fill whatever slots are
  left and move to another free slot when an online player needs theirs.
- **New players:** a player in their first session always gets one of
  fill slots 1–4 (FTUE walks ≤ ~16 s).
- **Spawns:**
  - First session: spawn in the Plaza, just inside the arch, facing the
    bowl, with the FTUE first node ahead (§6).
  - Later joins: spawn at your own bridge mouth (Rim road end).
  - **After any death** (combat, fall, reset): respawn in the Plaza.
    Never at home. This stops "jump off to teleport home" from beating
    D3. A carrier who dies still drops the loot home (D111, unchanged).
- **Home beacon:** a soft pillar of light in the player's colour above
  their own plot, visible only to them (client-only). **No teleport
  buttons** anywhere; they would let owners skip the run home in a Chase.

---

## 11. Legibility (R1-08c)

- **Plot identity:** each plot gets a colour and a big number banner at
  its bridge mouth. The banner **flashes while that plot is being raided**
  (who's being robbed, no text).
- **Milestones:** numbered stone posts in the owner's colour at each
  bridge mouth.
- **Signpost:** owner name, Level, and pictograms for gems on pedestals.
- **Offline lanterns:** owner-colour lanterns at the bridge mouth dim
  while the owner is offline (RW2 made visible).
- **Pictogram signs:** coin = NPC buyer, anvil = Crafting Bench, Scav
  mask = Scav Camp.
- **Compass mosaic:** a floor mosaic in the Pit with 10 rays, each tinted
  to the rim slot it points at.
- **Rails:** on bridges and the Rim road's void edges (§3.1).
- All of these obey §4 rules 4 and 5.

---

## 12. Greybox colour key

Set once in `Config.GreyboxPalette`; applied to `Visual` only.

| Colour | Means | Used on |
|---|---|---|
| Grey | Neutral walkable | Rim road, slope, bridges |
| Owner hue (8) | Someone's base | Plot trim, banner, milestone, lanterns |
| Green | Safe / services | Plaza, buyer, bench |
| Red + hazard stripes | Danger | Scav Camp, Burrow grate, Gate island |
| Gold | Reward | Mining nodes, vein spots, Pit floor accents |
| Purple | Landmark | Spire |
| White, dashed edge | Closed / later | Reaches barricade, reserved station slots |

- Pair every colour with a material or pattern (colour-blind players).
- **Neon is reserved for gems** so they always pop (RW13).
- Studio-only debug toggle (`RunService:IsStudio()`) tints zones at full
  strength for layout review.

---

## 13. Ambience (client-only, no new systems)

R1 tier (build in R1-08c / R1-11):
- **Soundscapes:** wind on the Rim, echo in the Pit, bustle in the Plaza,
  scratching in the Burrow that builds before a wave (§5 telegraph).
- **Environmental story props:** rusted mine carts (they double as §5 juke
  cover), broken vault fragments on the slope, Scav tally-mark graffiti
  near the Burrow.

"R1 if time" tier (cut first if R1-11 runs long):
- Crystal moths drawn to glowing pedestals, bats circling the Pit.
- Clouds drifting under the island, rare crystal streaks across the skybox.

One client `LocalScript` runs all ambience, distance-culled (~150 studs
[PH]). It never affects gameplay.

---

## 14. Dressing tiers (Pit, Rim, skyline)

**R1:**
- Pit: compass mosaic (§11); a derelict drill rig + crane at the Pit edge
  (θ ≈ 126°, r ≈ 98 [PH]; ≤ 8 studs at ground level, non-climbable);
  lantern poles around the Pit (10, at r ≈ 106, midway between compass
  rays) that flare gold during a vein; seam cracks from each dormant vein
  spot toward the Burrow.
- Rim: rails, milestones, welcome arch framing the bowl from the Plaza.

**R1 if time** (Josh must ask for these; otherwise leave for later):
- Stone rings orbiting the Spire (above head height, non-collide).
- A dead conveyor spiralling down the slope (θ ≈ 210°–250°).
- Varied rock and crystal shapes under each plot's pillar (sizes
  identical).
- Two slow, deterministic searchlights from the Scav Camp over the Pit.
- A colossal fossil burrow-wyrm in the east cliff (θ ≈ 70°–110°).
- The vault-door dial turning one notch when each Rich Vein ends.
- A client-only trade blimp on a slow loop outside the cliffs.
- Distant quarry islands, a ringed planet in the skybox, crystal roots
  under the island, rock-gull flocks.

**Cut order if performance or time runs short:** skyline items first,
then the other "R1 if time" items. **Never cut** the compass mosaic,
rails, milestones, banners or Chase feedback: players need those to find
their way and not fall.

---

## 15. The world beyond the Rim

Three rings:
- **Play ring** (r ≤ ~285): §3.
- **Scenery ring** (r ≈ 275–900, see §4 rule 3 for set-backs): outer
  quarry cliffs, crystal-light waterfalls pouring into the void, floating
  debris, mine scaffolds, and the **vault door** forming the north cliff.
- **Vista ring** (1,024+ studs away): a custom skybox, plus at most a few
  huge silhouettes as `LevelOfDetail` imposters.

R1 builds the scenery ring as **greybox** (big simple shapes): cliffs,
vault door, cloud deck. Waterfalls and debris are "R1 if time". Art passes
come later.

---

## 16. Event looks (client-only, from existing server events)

- **Rich Vein eruption:** a crystal geyser at the active spot; the Pit
  floor accents light up; lantern poles flare gold. Visible from every
  plot.
- **Scav wave:** the Burrow grate glows red and dust rises (§5 telegraph).
- **Captain wave:** grate swings wide, Spire pulses (§5).
- **Active Chase:** Spire pulses red; the victim plot's banner flashes.
- Whole-map event reskins (seasonal, Vault Rush) are R2.

---

## 17. Lighting

- One fixed late-afternoon preset, warm, so crystals pop. No day/night.
- `Atmosphere` haze for depth.
- Choose **Future** or **ShadowMap** lighting by the R1-11 cheap-phone
  check; keep whichever holds 30 FPS [PH] in the Pit.

---

## 18. Performance and streaming

- `Workspace.StreamingEnabled = true` with Roblox's recommended settings:
  `StreamingMinRadius` 64, `StreamingTargetRadius` 1024,
  `ModelStreamingBehavior = Improved`, `StreamingIntegrityMode =
  PauseOutsideLoadedArea`, `StreamOutBehavior = Opportunistic`. Confirm
  current names and defaults on the Creator Hub before setting them.
- Each plot is its own model with `LevelOfDetail` so distant bases stay
  visible for scouting. Keep scenery as modular models (≤ ~64 studs
  across where possible).
- Verify imposters on a real phone (there are community reports of
  StreamingMesh imposters not rendering).
- **Server logic never depends on what a client has streamed** (R5).
- Particles and Neon, not dynamic lights. Burrow and Spire FX only for
  clients within ~150 studs [PH].
- **Worst case for the R1-11 cheap-phone check:** standing in the Pit
  with all 8 plots loaded, a vein, a wave and a Chase at once.

---

## 19. Tags and attributes (suggested; reuse existing ones)

| Tag | On | Attributes |
|---|---|---|
| `Plot` (existing) | each plot model | `PlotIndex` (existing), `FillSlot` 1–8, `Theta` |
| `Bridge<index>` (existing naming) | each plot bridge | — |
| `RimRoad` | Rim road parts | — |
| `PitFloor`, `Slope` | Pit and slope parts | — |
| `Spire` | Spire model | — |
| `ScavBurrow` | Burrow grate | `EmergeRadius` |
| `MiningNode` (or existing node tag) | each node | `Kind` Stone/Ore, `PairId` |
| `FtueFirstNode` | the FTUE node | — |
| `VeinSpot` | each vein spot | `VeinIndex` 1–3 |
| `ScavCamp` (existing derelict-vault tag if present) | camp model | `ExitDirection` |
| `GateIsland`, `ReachesBarricade` | Gate pieces | — |
| `Plaza`, `TruceZone` | Plaza island / zone volume | — |
| `PlazaSlot` | each station position | `Slot` = Buyer / Bench / Brazier / Shop / EventPad / Board |
| `SpawnPlaza`, `SpawnBridgeMouth` | spawn points | `PlotIndex` on bridge-mouth spawns |
| `Scenery`, `Decor` | non-gameplay models | — |
| `JukeCover` | Pit props that count as cover | — |

---

## 20. Not in R1 (R2 candidates)

- The vault door opens and the Reaches returns (live event); second Scav
  Camp in the Reaches.
- Rim cables become ziplines / launch pads (carriers can't use them;
  server-checked via R1-00).
- The trade blimp brings the rotating trader.
- Plaza: bench keeper's daily quests, event pad machines, the board,
  launch shop.
- Hidden crystal shards (badge + cosmetic) in reachable nooks.
- Seasonal Quarry reskins (Halloween first, if the weekly loop lands in
  late October); Vault Rush uses the Spire as its display; Scav Siege
  nights pour out of the Burrow.
- "Scav scout" wanderers only if the funnel shows dead stretches.

Explicitly **not** planned: perimeter paths around the outside of the
islands, climbable height, moving platforms or hazards, day/night,
VIP-only areas, teleport buttons.

---

## 21. Validation checklist

### 21.1 Script checks (R1-08a; add decor checks in R1-08c)
Write `docs-build/worldgen/validate_world.py` (or a `--check` mode in
`gen_world.py`) that reads the generated layout and fails loudly on:
1. Plot centre radii differ by more than 1 stud, or any bridge length
   differs by more than 1 stud.
2. Any plot's gate not facing the centre (±1°).
3. §4 rule 1: a public walkable surface within 40 studs of a plot is
   higher than that plot's floor.
4. §4 rule 2: any two islands, or an island and the Rim road, closer
   than 30 studs except along that island's own bridge.
5. §4 rule 3: any `Scenery` part within 30 studs of a walkable surface.
6. §4 rule 4: any `Decor` part within 40 studs of a plot with a
   collidable top surface above 3 studs.
7. Vein spots within 40 studs of the Plaza spawn.
8. Missing tags from §19.

### 21.2 Studio checks (Josh, with the item's "Done when")
- Walk: Plaza spawn → fill slot 1 ≈ 8 s; → fill slot 8 ≈ 25 s; plot →
  centre ≈ 13.5 s.
- A Scav can path from the Burrow to every plot's Scav ground.
- A Snatcher run takes about the same time from every plot.
- A carrier escapes at 140 studs on every plot (D111).
- Jumping off the Rim respawns you in the Plaza.
- Two clients can't damage each other in the Plaza; a carrier there can
  still be knocked loose.
- The cheap phone holds 30 FPS [PH] in the Pit with 8 plots loaded.
