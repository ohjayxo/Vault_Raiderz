# Perf spike (step 0B): results

**Device (all runs):** iPhone 14 Pro Max (a flagship), Roblox app, private place, landscape, graphics
Automatic, Low Power Mode made no difference. Taken 2026-09-20. Screenshots are in `~/Downloads`
(IMG_1295..1313, 1316, 1317; not in the repo).

**Units:** `cpu`/`gpu` are engine frame-time counters in **seconds** (`FT` read 0.0157-0.019 = one 60 FPS
frame), shown below in ms. `dc`/`tri` are the engine's real scene + shadow counts for the frame on screen.
CPU/GPU are the engine's *render* counters, not total game CPU (scripts, physics).

## Run 1: live readouts, HUD without engine counters

Every preset (Solo, Baseline, NoFx, Precise, Heavy, Extreme, Shard; Overview and Ground) held **60 FPS,
1% low 56-57**, memory 900-925 MB. Saturated at the frame cap: it ranks nothing. (Not repeated here.)

## Run 2: Record button (15 s averages), real counters

FPS is 60 avg / 57 1%-low in **every** row. Overview = fixed camera over all 9 islands (comparable
across presets). Ground depends on where the player stands, so Ground rows are NOT comparable.

| # | Preset | View | Mem MB | Claimed tris/parts | CPU ms | GPU ms | Draw calls | Real tris |
|---|---|---|---|---|---|---|---|---|
| 1 | Solo | Overview | 831 | 29k / 40 | 2.6 | 4.3 | 32 | 78k |
| 2 | Solo | Ground | 832 | | 3.0 | 5.7 | 74 | 166k |
| 3 | Varied | Overview | 923 | 230k / 264 | 4.0 | 6.8 | 125 | 293k |
| 4 | Varied | Ground | 938 | | 3.4 | 5.2 | 138 | 212k |
| 5 | Extreme (4x) | Overview | 956 | 597k / 939 | 3.9 | 14.3 | 65 | 658k |
| 6 | Extreme | Ground | 954 | | 3.4 | 5.3 | 76 | 207k |
| 7 | Limit (8x) | Overview | 998 | 1,086k / 1,839 | 4.0 | 11.2 | 66 | 1,150k |
| 8 | Limit | Ground | 991 | | 3.2 | 5.3 | 76 | 279k |
| 9 | Over (16x) | Overview | 1,031 | 2,066k / 3,639 | 4.1 | 15.4 | 65 | 2,129k |
| 10 | Over | Ground | 1,029 | | 2.8 | 5.3 | 64 | 180k |
| 11 | Solo (again) | Overview | 1,017 | 29k / 40 | 2.8 | 4.5 | 32 | 78k |
| 12 | Solo (again) | Ground | 1,021 | | 3.1 | 5.8 | 69 | 157k |

Baseline (unvaried) was not recorded in this session. **Precise is identical to Baseline** (scripts
can't set LOD), so use its rows from the earlier session, same phone:

| Preset | View | Mem MB | CPU ms | GPU ms | Draw calls | Real tris |
|---|---|---|---|---|---|---|
| Precise (= Baseline) | Overview | 996 | 3.8 | 10.2 | 65 | 292k |
| Precise (= Baseline) | Ground | 990 | 2.8 | 5.7 | 95 | 281k |
| NoFx | Overview | 988 | 3.2 | 7.3 | 24 | 251k |
| NoFx | Ground | 988 | 3.0 | 5.3 | 62 | 164k |
| Heavy (2x) | Ground | 992 | 2.9 | 8.0 | 92 | 345k |
| Shard | Overview | 988 | 3.2 | 5.4 | 66 | 168k |
| Shard | Ground | 988 | 3.2 | 5.1 | 88 | 205k |

Studio desktop (Ground): Baseline 87-92 dc / 186-204k tri; Varied 133 dc / 186k tri.

## What it shows (see the chat interpretation for reasoning)

1. **No crash and 60 FPS avg at Over**: 2.1M real triangles (2.1x the docs' ~1M budget), 3,639 parts.
2. **Draw calls do not scale with piece count**: ~65 in Overview at 264 parts and at 3,639 parts.
   Repeated meshes are batched. **Different materials split batches**: Varied doubled Overview draw
   calls (65 to 125) at identical pieces/triangles. So D57's piece budget is the wrong unit.
3. **GPU time is the limit, and it is noisy.** Overview GPU: 4.3 ms (1 base) up to 14-15 ms at
   0.66-2.1M triangles, vs a 16.7 ms frame at 60 FPS. Over is close to this phone's 60 FPS ceiling.
   Readings vary by 2-3 ms between sessions/views (Limit 11.2 < Extreme 14.3; Heavy/Ground 8.0 > Limit/
   Ground 5.3), so treat GPU ms as +/- 3 ms.
4. **CPU render time flat** (2.6-4.1 ms) across all presets: not the bottleneck here.
5. Memory climbs with history and does not come back (831 MB at first Solo; 1,017 MB Solo again after
   the heavy presets). Peak ~1.03 GB, no kill. Docs give no memory limit.
6. Engine triangle count in Overview ~= the kit's claimed count (2,129k real vs 2,066k claimed), so
   automatic LOD removed nothing from these small meshes.

## Still open (step 0 is NOT fully met)

- A real cheap phone has not been tested. Everything above is a best case.
- Whether the docs' ~1,000,000-triangle budget suits the *baseline device* depends on how much slower that
  device is than this one; unknown.
- Bring the numbers back to the design project (D57 unit, LOD rules) before step 4.
